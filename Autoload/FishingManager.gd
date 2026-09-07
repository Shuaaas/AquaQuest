extends Node
## FishingManager (Autoload Singleton)
##
## Single responsibility: control the fishing FLOW, start to finish. It
## does not load or grade questions (QuestionManager's job), does not
## decide difficulty (DDAController's job), does not own item/score data
## beyond a running point total (InventoryManager owns items), and does
## not render or animate anything itself - it only emits signals that a
## fishing UI and a fishing animation component react to.
##
## FULL FLOW (Phase 5):
##   FishingSpot.interact() -> EventBus.fishing_started (quest + rod
##       already gated by FishingSpot itself before this ever fires)
##     -> CASTING: fishing_cast_started, wait for cast animation duration
##     -> WAITING: fishing_wait_started, wait a random bite delay
##     -> fish_bit fires, wait animation should freeze immediately
##     -> a question is drawn from QuestionManager at the current DDA tier
##     -> fishing_question_ready -> UI calls submit_answer(index)
##   CORRECT answer:
##     -> points awarded, a fish item awarded (species resolved per-spot),
##        quest progress updated if the spot requires one
##     -> REELING: fishing_reel_started(spot_id, true) - "reeling it in"
##        completion animation plays
##     -> fishing_ended(true)
##   INCORRECT answer:
##     -> points deducted, a Mini Quest question begins instead of ending
##        the attempt yet (no reel here - the line hasn't been reeled in,
##        the player gets a second chance first)
##     -> mini_quest_question_ready -> UI calls submit_mini_quest_answer(index)
##     CORRECT mini quest answer:
##       -> half the deducted points are restored
##       -> REELING: fishing_reel_started(spot_id, false) - the attempt is
##          now truly over (no fish caught either way), line reeled in
##       -> fishing_ended(false), flow resets to IDLE so the player can
##          immediately interact again for a fresh attempt at the SAME spot
##     INCORRECT mini quest answer:
##       -> DESIGN DECISION (not specified in the brief): the attempt ends
##          entirely here too - same REELING beat, then fishing_ended(false).
##          No further retry loop. If a different penalty is wanted, this
##          is the one place to change - see submit_mini_quest_answer() below.
##
## Every path that ends an attempt - success, mini-quest resolution either
## way, or even the no-question-available edge cases - funnels through the
## single _finish_attempt() helper below. This was a deliberate refactor:
## earlier, a couple of edge-case paths (no question available at bite
## time, or at mini-quest time) emitted fishing_ended directly WITHOUT ever
## going through this REELING beat, which meant a FishingAnimationComponent
## listening for "when do I unfreeze the sprite after a bite" would leave
## the sprite stuck on its frozen fish_bit frame forever on those paths.
## Centralizing here fixes that for every current and future ending path.
##
## FISH SPECIES: per-spot reward pools are read from the FishingSpot's own
## `possible_fish_ids` export (see FishingSpot.gd) at the moment a catch
## resolves - FishingManager never hardcodes species and never needs to
## know a spot exists ahead of time. A spot with no species configured
## falls back to PLACEHOLDER_FISH_ITEM_ID, so existing test spots keep
## working unchanged.
##
## NOT YET BUILT (same "hook, not full system" honesty as other phases):
## fish rarity/weighting, a real point-persistence/leaderboard concept
## (points reset to 0 on game restart right now - not wired into
## SaveManager yet), and multiple simultaneous fishing sessions
## (single-player scope, same assumption the rest of this project makes).

enum FlowState { IDLE, CASTING, WAITING, AWAITING_MAIN_ANSWER, AWAITING_MINI_ANSWER, REELING }

const PLACEHOLDER_FISH_ITEM_ID := "fish"

const POINTS_PER_CATCH := 10
const POINTS_PENALTY_ON_MISS := 5

const CAST_DURATION_SECONDS := 1.0
const WAIT_DURATION_MIN_SECONDS := 1.5
const WAIT_DURATION_MAX_SECONDS := 4.0
const REEL_DURATION_SECONDS := 0.8

var _state: FlowState = FlowState.IDLE
var _current_spot_id: String = ""
var _current_question: Dictionary = {}
var _current_mini_question: Dictionary = {}
var _pending_penalty_to_refund: int = 0

var _points: int = 0


func _ready() -> void:
	EventBus.fishing_started.connect(_on_fishing_started)


func get_points() -> int:
	return _points


func _on_fishing_started(spot_id: String) -> void:
	if _state != FlowState.IDLE:
		push_warning("FishingManager: fishing_started for '%s' while already mid-flow, ignoring" % spot_id)
		return

	_current_spot_id = spot_id
	_state = FlowState.CASTING
	EventBus.fishing_cast_started.emit(spot_id)

	await get_tree().create_timer(CAST_DURATION_SECONDS).timeout
	if _state != FlowState.CASTING or _current_spot_id != spot_id:
		return  # flow was reset/cancelled while we were waiting

	_state = FlowState.WAITING
	EventBus.fishing_wait_started.emit(spot_id)

	var wait_time := randf_range(WAIT_DURATION_MIN_SECONDS, WAIT_DURATION_MAX_SECONDS)
	await get_tree().create_timer(wait_time).timeout
	if _state != FlowState.WAITING or _current_spot_id != spot_id:
		return

	_trigger_bite(spot_id)


func _trigger_bite(spot_id: String) -> void:
	# Per spec: "Immediately pause the fishing animation" the instant a fish
	# bites, before the question even appears - a FishingAnimationComponent
	# freezes on this same signal.
	EventBus.fish_bit.emit(spot_id)

	var tier: int = DDAController.get_current_tier()
	var question := QuestionManager.get_random_question(tier)

	if question.is_empty():
		EventBus.fishing_denied.emit(spot_id, "no_question_available")
		await _finish_attempt(spot_id, false)
		return

	_current_question = question
	_state = FlowState.AWAITING_MAIN_ANSWER
	EventBus.fishing_question_ready.emit(spot_id, question)


## Called by the fishing UI when the player answers the MAIN question.
func submit_answer(answer_index: int) -> void:
	if _state != FlowState.AWAITING_MAIN_ANSWER:
		push_warning("FishingManager: submit_answer called with no active question, ignoring")
		return

	var question_id: String = _current_question.get("id", "")
	var was_correct := QuestionManager.evaluate_answer(question_id, answer_index)
	EventBus.question_answered.emit(question_id, was_correct)

	var spot_id := _current_spot_id

	if was_correct:
		_award_points(POINTS_PER_CATCH)
		_award_catch(spot_id)
		await _finish_attempt(spot_id, true)
	else:
		_pending_penalty_to_refund = POINTS_PENALTY_ON_MISS
		_award_points(-POINTS_PENALTY_ON_MISS)
		_start_mini_quest(spot_id)


## Triggered by a wrong main answer. Draws one question a tier easier than
## the player's current DDA tier (clamped to EASY), falling back to the
## same tier if no easier question exists yet, so this never silently
## soft-locks a region that only has one difficulty of content authored.
## No REELING beat happens here - the line isn't reeled in yet, the player
## gets a second chance first.
func _start_mini_quest(spot_id: String) -> void:
	var main_tier: int = DDAController.get_current_tier()
	var mini_tier: int = max(main_tier - 1, DDAController.DifficultyTier.EASY)

	var question := QuestionManager.get_random_question(mini_tier)
	if question.is_empty():
		question = QuestionManager.get_random_question(main_tier)

	if question.is_empty():
		# No question available at any nearby tier - end the attempt rather
		# than leave the player stuck with no way to proceed.
		await _finish_attempt(spot_id, false)
		return

	_current_mini_question = question
	_state = FlowState.AWAITING_MINI_ANSWER
	EventBus.mini_quest_question_ready.emit(spot_id, question)


## Called by the fishing UI when the player answers the MINI QUEST question.
func submit_mini_quest_answer(answer_index: int) -> void:
	if _state != FlowState.AWAITING_MINI_ANSWER:
		push_warning("FishingManager: submit_mini_quest_answer called with no active mini quest, ignoring")
		return

	var question_id: String = _current_mini_question.get("id", "")
	var was_correct := QuestionManager.evaluate_answer(question_id, answer_index)
	EventBus.question_answered.emit(question_id, was_correct)

	var spot_id := _current_spot_id

	if was_correct:
		var refund := int(_pending_penalty_to_refund / 2.0)
		_award_points(refund)
	# See the class doc's "INCORRECT mini quest answer" note - both branches
	# end the attempt the same way (no fish caught either way), they only
	# differ in whether points were refunded above.

	await _finish_attempt(spot_id, false)


## The single place every ending path funnels through - see the class doc
## for why this was centralized. Plays the REELING beat, then closes out
## the attempt and resets to IDLE.
func _finish_attempt(spot_id: String, success: bool) -> void:
	print("REELING started - success: ", success)
	_state = FlowState.REELING
	EventBus.fishing_reel_started.emit(spot_id, success)

	await get_tree().create_timer(REEL_DURATION_SECONDS).timeout

	EventBus.fishing_ended.emit(spot_id, success)
	_reset_to_idle()


func _award_points(delta: int) -> void:
	_points += delta
	EventBus.fishing_points_changed.emit(_points, delta)


#func _award_catch(spot_id: String) -> void:
	#InventoryManager.add_item(_resolve_reward_item_id(spot_id))
#
	#var quest_id := _get_required_quest_id(spot_id)
	#if quest_id != "":
		#QuestManager.update_quest_progress(quest_id, {"last_result": "caught"})
		
func _award_catch(spot_id: String) -> void:
	InventoryManager.add_item(_resolve_reward_item_id(spot_id))

	var quest_id := _get_required_quest_id(spot_id)
	if quest_id != "":
		var progress := QuestManager.get_quest_progress(quest_id).duplicate()
		progress["last_result"] = "caught"
		QuestManager.update_quest_progress(quest_id, progress)


## See FISH SPECIES note in the class doc above.
func _resolve_reward_item_id(spot_id: String) -> String:
	var possible_ids := _get_possible_fish_ids(spot_id)
	if possible_ids.is_empty():
		return PLACEHOLDER_FISH_ITEM_ID
	return possible_ids[randi() % possible_ids.size()]


func _get_possible_fish_ids(spot_id: String) -> Array:
	var spot := _find_fishing_spot(spot_id)
	if spot == null or spot.possible_fish_ids.is_empty():
		return []
	return spot.possible_fish_ids


func _get_required_quest_id(spot_id: String) -> String:
	var spot := _find_fishing_spot(spot_id)
	return spot.required_quest_id if spot != null else ""


func _find_fishing_spot(spot_id: String) -> FishingSpot:
	for spot in get_tree().get_nodes_in_group("fishing_spots"):
		if spot is FishingSpot and spot.spot_id == spot_id:
			return spot
	return null


func _reset_to_idle() -> void:
	_state = FlowState.IDLE
	_current_spot_id = ""
	_current_question = {}
	_current_mini_question = {}
	_pending_penalty_to_refund = 0
