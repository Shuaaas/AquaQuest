extends Node
## FishingManager (Autoload Singleton)
##
## Single responsibility: control the fishing FLOW, start to finish. It
## does not load or grade questions (QuestionManager's job), does not
## decide difficulty (DDAController's job), does not own location data
## (FishingAreaManager's job, added Phase 8), does not own item/score data
## beyond a running point total, and does not render or animate anything
## itself - it only emits signals and calls GameManager for pause/resume.
##
## FULL FLOW (Phase 5, extended Phase 8):
##   FishingSpot.interact() -> EventBus.fishing_started (quest + rod +
##       required-rod-id already gated by FishingSpot itself before this
##       ever fires)
##     -> CASTING: fishing_cast_started, wait for cast animation duration
##     -> WAITING: fishing_wait_started, wait a random bite delay
##     -> fish_bit fires, wait animation should freeze immediately
##     -> a question is drawn (see QUESTION DRAWING below) at the current
##        DDA tier -> GameManager.set_paused(true) -> fishing_question_ready
##        -> UI calls submit_answer(index)
##   CORRECT answer:
##     -> points awarded, a fish item awarded (species resolved per-spot
##        or per-location, see FISH SPECIES below), quest progress updated
##     -> _finish_attempt: GameManager.set_paused(false) FIRST (per spec:
##        "Resume after answering"), THEN REELING animation, THEN
##        fishing_ended(true)
##   INCORRECT answer:
##     -> points deducted, a Mini Quest question begins instead of ending
##        the attempt yet (gameplay STAYS paused through this - the player
##        is still "answering," just on a second chance)
##     -> mini_quest_question_ready -> UI calls submit_mini_quest_answer(index)
##     CORRECT mini quest answer:
##       -> half the deducted points are restored
##       -> _finish_attempt: unpause, REELING(false), fishing_ended(false),
##          flow resets to IDLE so the player can immediately interact
##          again for a fresh attempt at the SAME spot
##     INCORRECT mini quest answer:
##       -> DESIGN DECISION (not specified in the brief): the attempt ends
##          entirely here too - unpause, same REELING beat, fishing_ended(false).
##          No further retry loop. If a different penalty is wanted, this
##          is the one place to change - see submit_mini_quest_answer() below.
##
## Every path that ends an attempt - success, mini-quest resolution either
## way, or even the no-question-available edge cases - funnels through the
## single _finish_attempt() helper below, which is also the ONLY place
## that unpauses. This guarantees gameplay can never get stuck paused,
## the same centralization that already fixed a sprite-stuck bug earlier.
##
## QUESTION DRAWING (Phase 8): if the spot being fished has a `location_id`
## (see FishingSpot.gd), _draw_question() resolves that location's
## `lesson_id` and `question_pool` from FishingAreaManager and passes them
## into QuestionManager.get_random_question()'s existing/new optional
## parameters. A spot with no location_id draws exactly as it did before
## this phase - no lesson filter, no pool restriction.
##
## FISH SPECIES (Phase 5, extended Phase 8): reward resolution now tries,
## in order: (1) the spot's own `possible_fish_ids` override, unchanged
## from Phase 5; (2) the spot's `location_id`'s WEIGHTED fish_species list
## via FishingAreaManager, new this phase; (3) PLACEHOLDER_FISH_ITEM_ID.
## Existing spots using only possible_fish_ids are completely unaffected.
##
## NOT YET BUILT (same "hook, not full system" honesty as other phases):
## a real point-persistence/leaderboard concept (points reset to 0 on
## game restart right now), and multiple simultaneous fishing sessions
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
	# freezes on this same signal. Note this is the ANIMATION pause, not
	# GAMEPLAY pause - gameplay only pauses once a real question is about
	# to be shown, a few lines down.
	EventBus.fish_bit.emit(spot_id)

	var tier: int = DDAController.get_current_tier()
	var question := _draw_question(spot_id, tier)

	if question.is_empty():
		EventBus.fishing_denied.emit(spot_id, "no_question_available")
		await _finish_attempt(spot_id, false)
		return

	_current_question = question
	_state = FlowState.AWAITING_MAIN_ANSWER
	# Per spec: "Pause gameplay. Open the Question UI." - pause first, then
	# fire the signal that opens the UI, so nothing can move/act underneath it.
	GameManager.set_paused(true)
	EventBus.fishing_question_ready.emit(spot_id, question)


## Resolves a question for this spot, honoring its location's lesson_id/
## question_pool if it has one (Phase 8). Falls back to an unfiltered draw
## for spots with no location_id, identical to pre-Phase-8 behavior.
func _draw_question(spot_id: String, tier: int) -> Dictionary:
	var spot := _find_fishing_spot(spot_id)
	if spot == null or spot.location_id == "":
		return QuestionManager.get_random_question(tier)

	var location := FishingAreaManager.get_location(spot.location_id)
	var lesson_id: String = location.get("lesson_id", "")
	var question_pool: Array = location.get("question_pool", [])
	return QuestionManager.get_random_question(tier, lesson_id, question_pool)


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
## No REELING beat and no unpause happens here - gameplay is still paused
## from the main question, the player gets a second chance before anything
## resumes.
func _start_mini_quest(spot_id: String) -> void:
	var main_tier: int = DDAController.get_current_tier()
	var mini_tier: int = max(main_tier - 1, DDAController.DifficultyTier.EASY)

	var question := _draw_question(spot_id, mini_tier)
	if question.is_empty():
		question = _draw_question(spot_id, main_tier)

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
## for why this was centralized. Unpauses gameplay FIRST (per spec:
## "Resume after answering"), then plays the REELING beat, then closes
## out the attempt and resets to IDLE.
func _finish_attempt(spot_id: String, success: bool) -> void:
	GameManager.set_paused(false)

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



## See FISH SPECIES note in the class doc above - tries the spot's own
## override first, then its location's weighted species, then the
## generic placeholder.
func _resolve_reward_item_id(spot_id: String) -> String:
	var possible_ids := _get_possible_fish_ids(spot_id)
	if not possible_ids.is_empty():
		return possible_ids[randi() % possible_ids.size()]

	var spot := _find_fishing_spot(spot_id)
	if spot != null and spot.location_id != "":
		var weighted_pick := FishingAreaManager.pick_weighted_species(spot.location_id)
		if weighted_pick != "":
			return weighted_pick

	return PLACEHOLDER_FISH_ITEM_ID


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
