extends Node
## FishingManager (Autoload Singleton)
##
## Single responsibility: control the fishing FLOW. It does not load or
## grade questions (QuestionManager's job), does not decide difficulty
## (DDAController's job), does not own item data (InventoryManager's job),
## and does not render anything (a fishing UI scene's job, reacting to
## EventBus). FishingManager only sequences those systems together:
##
##   FishingSpot.interact() -> EventBus.fishing_started
##       -> FishingManager asks DDAController for the current tier
##       -> FishingManager asks QuestionManager for a question at that tier
##       -> EventBus.fishing_question_ready (a fishing UI shows it)
##       -> UI calls FishingManager.submit_answer(index)
##       -> FishingManager asks QuestionManager to grade it
##       -> EventBus.question_answered (DDAController updates itself, as it
##          already does today - no change needed there)
##       -> correct  -> InventoryManager.add_item(<caught fish>), fishing_ended(true)
##       -> incorrect -> fishing_ended(false), no item awarded
##
## FISH REWARD HOOK: `_resolve_reward_item_id()` currently returns a single
## generic "fish" item id as a placeholder. Once a real fish catalog exists
## (per-region/per-spot catch tables), replace only that one method - the
## rest of the flow above does not need to change.

enum FlowState { IDLE, AWAITING_ANSWER }

const PLACEHOLDER_FISH_ITEM_ID := "fish"

var _state: FlowState = FlowState.IDLE
var _current_spot_id: String = ""
var _current_question: Dictionary = {}


func _ready() -> void:
	EventBus.fishing_started.connect(_on_fishing_started)


func _on_fishing_started(spot_id: String) -> void:
	if _state != FlowState.IDLE:
		push_warning("FishingManager: fishing_started for '%s' while already mid-flow, ignoring" % spot_id)
		return

	var tier: int = DDAController.get_current_tier()
	var question := QuestionManager.get_random_question(tier)

	if question.is_empty():
		EventBus.fishing_denied.emit(spot_id, "no_question_available")
		return

	_current_spot_id = spot_id
	_current_question = question
	_state = FlowState.AWAITING_ANSWER

	EventBus.fishing_question_ready.emit(spot_id, question)


## Called by the fishing UI when the player picks an answer.
func submit_answer(answer_index: int) -> void:
	if _state != FlowState.AWAITING_ANSWER:
		push_warning("FishingManager: submit_answer called with no active question, ignoring")
		return

	var question_id: String = _current_question.get("id", "")
	var was_correct := QuestionManager.evaluate_answer(question_id, answer_index)

	EventBus.question_answered.emit(question_id, was_correct)
	_resolve_catch(was_correct)


func _resolve_catch(was_correct: bool) -> void:
	var spot_id := _current_spot_id

	if was_correct:
		InventoryManager.add_item(_resolve_reward_item_id())

	EventBus.fishing_ended.emit(spot_id, was_correct)

	_state = FlowState.IDLE
	_current_spot_id = ""
	_current_question = {}


## Placeholder reward resolution - see FISH REWARD HOOK note above.
func _resolve_reward_item_id() -> String:
	return PLACEHOLDER_FISH_ITEM_ID
