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
##     -> WAITING: fishing_wait_started, wait a bite delay whose range
##        comes from DDAController.get_bite_wait_range() (Phase 11 -
##        Adaptation 3: Fish Bite Timing - varies by current tier)
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
##     -> points deducted, a reinforcement message shows immediately
##        (Phase 10 - surfaces the ORIGINAL question's explanation as
##        encouragement, not punishment - see _show_concept_feedback())
##     -> a Mini Quest REINFORCEMENT LOOP begins instead of ending the
##        attempt (gameplay STAYS paused through the whole loop - the
##        player is still "answering," just working through it)
##     -> mini_quest_question_ready -> UI calls submit_mini_quest_answer(index)
##     CORRECT mini quest answer:
##       -> half the deducted points are restored
##       -> the ORIGINAL main question is RESUMED - the exact same stored
##          Dictionary re-emitted via fishing_question_ready, never
##          replaced by a new random question - and the player answers it
##          again. The attempt only actually ends once this resumed main
##          question is answered CORRECTLY (looping back through this same
##          INCORRECT branch again if failed once more - see
##          submit_answer()'s own comment on this).
##     INCORRECT mini quest answer:
##       -> the loop CONTINUES - another question related to the same
##          concept is shown (see get_related_question() in
##          QuestionManager.gd), not a new random unrelated one, and not
##          the end of the attempt. This repeats until the player answers
##          one correctly - there is no way to bypass the Mini Quest
##          without demonstrating understanding. See _start_mini_quest()
##          and submit_mini_quest_answer() below for the full mechanism.
##
## Every path that ends an attempt - success (whether on the first try or
## after resuming from a reinforcement loop), or the no-question-available
## edge cases - funnels through the single _finish_attempt() helper below,
## which is also the ONLY place that unpauses. This guarantees gameplay
## can never get stuck paused, the same centralization that already fixed
## a sprite-stuck bug earlier.
##
## MINI QUEST RELATEDNESS: reinforcement questions are chosen by
## QuestionManager.get_related_question(), which prefers a SIMPLER
## question (lower tier) sharing the same `concept_id` as whatever was
## just failed - not an unrelated random draw. A question without
## `concept_id` set falls back to the old tier-based random draw, so
## existing content without that field keeps working, just without true
## conceptual relatedness until it's authored in.
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
const REEL_DURATION_SECONDS := 0.8

var _state: FlowState = FlowState.IDLE
var _current_spot_id: String = ""
var _current_question: Dictionary = {}
var _current_mini_question: Dictionary = {}
## Tracks which reinforcement question ids have been shown THIS
## reinforcement loop (reset on each NEW main-question failure), so
## _start_mini_quest doesn't immediately repeat the same question and so
## the "first round" of a loop can be detected (is_empty()) for the
## once-per-loop mini_quest_triggered signal.
var _mini_quest_seen_ids: Array = []
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

	# Phase 11 (DDA Adaptation 3 - Fish Bite Timing): range now comes from
	# DDAController instead of fixed constants, varying by current tier.
	var wait_range: Vector2 = DDAController.get_bite_wait_range()
	var wait_time := randf_range(wait_range.x, wait_range.y)
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
		_show_concept_feedback(question_id, "Not quite - let's review and try again!")
		# A NEW reinforcement loop starts here - reset the seen-ids list so
		# _start_mini_quest treats this as round 1 (fires mini_quest_triggered
		# once, and won't accidentally think a question from some earlier,
		# already-finished loop is "already seen"). Note this also covers the
		# case where _current_question is a RESUMED main question that was
		# failed again after an earlier successful reinforcement round - each
		# fresh failure of the main question, resumed or original, starts its
		# own new loop, per the existing point-penalty rule applying every time.
		_mini_quest_seen_ids = []
		_start_mini_quest(spot_id)


## Phase 10: the actual new piece this phase needed. Surfaces the ORIGINAL
## question's explanation immediately, framed as encouragement rather than
## punishment - "this reinforces learning instead of punishing mistakes"
## per the brief. This is DISTINCT from the final result toast
## (FishingUI._on_fishing_ended), which shows the MINI QUEST question's own
## explanation once the whole attempt concludes - so a player who gets the
## main question wrong sees two educational touchpoints: what they missed,
## right away, and confirmation of the related concept once they've had a
## chance to prove they understood it.
## Phase 10: surfaces a question's explanation as encouragement, not
## punishment - "this reinforces learning instead of punishing mistakes"
## per the brief. Generalized (Mini Quest Reinforcement fix) to work for
## ANY feedback moment (initial main-question failure, a wrong
## reinforcement answer, or a passed reinforcement round) rather than
## being hardcoded to only the first case.
func _show_concept_feedback(question_id: String, lead_in: String) -> void:
	var explanation: String = QuestionManager.get_question_by_id(question_id).get("explanation", "")
	var message := lead_in
	var duration := 2.0
	if explanation != "":
		message += " " + explanation
		duration = 4.5
	# Phase 11 (DDA Adaptation 5 - Educational Assistance): EASY tier gets
	# more time to read/absorb the explanation, HARD gets less.
	duration *= DDAController.get_explanation_duration_multiplier()
	UIManager.show_notification(message, duration)


## Triggered by a wrong main answer, OR by a wrong reinforcement answer
## continuing the SAME loop. Draws a question RELATED to the concept
## behind the currently-failed question (_current_question if this is
## the first round, _current_mini_question if continuing a loop) via
## QuestionManager.get_related_question() - falling back to the old
## tier-based unrelated random draw ONLY if that question has no
## concept_id set (keeps existing content without concept_id working
## exactly as before, just without true relatedness).
##
## No REELING beat and no unpause happens here - gameplay is still paused
## from the main question, the player gets a second chance before anything
## resumes.
func _start_mini_quest(spot_id: String) -> void:
	# Whichever question is CURRENTLY the one the player just failed -
	# either the original main question (round 1) or the previous
	## reinforcement question (a repeat round within the same loop).
	var failed_question: Dictionary = _current_mini_question if not _mini_quest_seen_ids.is_empty() else _current_question
	var concept_id: String = failed_question.get("concept_id", "")
	var preferred_tier: int = failed_question.get("tier", DDAController.get_current_tier())

	# Fires exactly once per loop - see EventBus.mini_quest_triggered's own
	# doc comment for why this must be separate from mini_quest_question_ready.
	if _mini_quest_seen_ids.is_empty():
		EventBus.mini_quest_triggered.emit(spot_id)

	# BUGFIX: _mini_quest_seen_ids alone isn't enough to exclude - it starts
	# EMPTY on round 1, which meant the original main question's own id was
	# never excluded on the first call, so the "reinforcement" question
	# could end up being the exact same question the player just failed.
	# The original main question's id must always be excluded, every round,
	# regardless of how many mini-quest rounds have happened.
	var exclude_ids: Array = _mini_quest_seen_ids.duplicate()
	var original_question_id: String = _current_question.get("id", "")
	if original_question_id != "" and not exclude_ids.has(original_question_id):
		exclude_ids.append(original_question_id)

	var question := QuestionManager.get_related_question(concept_id, preferred_tier, exclude_ids)

	if question.is_empty():
		# No concept_id on the failed question (or no related content
		# authored yet) - fall back to the old tier-based unrelated draw,
		# exactly the pre-fix behavior, so content without concept_id keeps
		# working rather than dead-ending.
		var main_tier: int = DDAController.get_current_tier()
		var mini_tier: int = max(main_tier - 1, DDAController.DifficultyTier.EASY)
		question = _draw_question(spot_id, mini_tier)
		if question.is_empty():
			question = _draw_question(spot_id, main_tier)

	if question.is_empty():
		# No question available anywhere - end the attempt rather than
		# leave the player stuck with no way to proceed.
		await _finish_attempt(spot_id, false)
		return

	_mini_quest_seen_ids.append(question.get("id", ""))
	_current_mini_question = question
	_state = FlowState.AWAITING_MINI_ANSWER
	EventBus.mini_quest_question_ready.emit(spot_id, question)


## Called by the fishing UI when the player answers the MINI QUEST question.
##
## CORE FIX: a wrong answer here no longer ends the attempt. It stays in
## the reinforcement loop, showing another related question, until the
## player answers one correctly - matching "the player must eventually
## answer the Mini Quest correctly before the Main Quest can resume."
## A correct answer does NOT finish the attempt either - it resumes the
## ORIGINAL main question (never replaced by a new random one) by
## re-emitting fishing_question_ready with the SAME stored _current_question,
## reusing FishingUI's existing rendering with no new UI code needed.
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
		_pending_penalty_to_refund = 0
		_show_concept_feedback(question_id, "Concept reinforced! Let's try that question again.")

		# Resume the ORIGINAL main question - same stored Dictionary, not a
		# fresh draw. FishingUI already knows how to render this via the
		# exact signal it was already listening to for the first attempt.
		_current_mini_question = {}
		_mini_quest_seen_ids = []
		_state = FlowState.AWAITING_MAIN_ANSWER
		EventBus.fishing_question_ready.emit(spot_id, _current_question)
	else:
		_show_concept_feedback(question_id, "Still not quite - let's try a related question.")
		# Stay in the SAME loop - _mini_quest_seen_ids already has this
		# question's id, so _start_mini_quest won't immediately repeat it,
		# and won't re-fire mini_quest_triggered (the list isn't empty).
		_start_mini_quest(spot_id)


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
	_mini_quest_seen_ids = []
	_pending_penalty_to_refund = 0
