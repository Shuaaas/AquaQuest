extends Node
## DDAController (Autoload Singleton)
##
## Core Dynamic Difficulty Adjustment engine for AquaQuest's exam/question
## system. Listens to question_answered results, maintains a rolling
## performance metric per player, and raises/lowers a difficulty tier that
## the exam/question-selection system reads to pick which question pool to
## draw from. This script only produces a *recommendation* (the tier) - it
## does not select questions or alter UI, keeping DDA logic isolated and
## independently testable/tunable without touching exam or question code.
##
## Framework only: no gameplay-specific thresholds are tuned here yet,
## just the mechanism. Tune WINDOW_SIZE / thresholds once real question
## data exists.

enum DifficultyTier { EASY, MEDIUM, HARD }

## Number of recent answers considered for the rolling accuracy calculation.
const WINDOW_SIZE := 5
## Accuracy above this promotes the player a tier.
const PROMOTE_THRESHOLD := 0.8
## Accuracy below this demotes the player a tier.
const DEMOTE_THRESHOLD := 0.4

var current_tier: DifficultyTier = DifficultyTier.MEDIUM
# true/false per recent answer, oldest first, capped at WINDOW_SIZE
var _recent_results: Array[bool] = []


func _ready() -> void:
	EventBus.question_answered.connect(_on_question_answered)
	SaveManager.register_section("dda", _get_save_data, _apply_save_data)


func _on_question_answered(_question_id: String, was_correct: bool) -> void:
	_recent_results.append(was_correct)
	if _recent_results.size() > WINDOW_SIZE:
		_recent_results.pop_front()

	if _recent_results.size() < WINDOW_SIZE:
		return # not enough data yet to make a confident adjustment

	_evaluate_difficulty()


func _evaluate_difficulty() -> void:
	var correct_count := 0
	for result: bool in _recent_results:
		if result:
			correct_count += 1
	var accuracy: float = float(correct_count) / float(_recent_results.size())

	var previous_tier := current_tier

	if accuracy >= PROMOTE_THRESHOLD and current_tier < DifficultyTier.HARD:
		current_tier += 1
	elif accuracy <= DEMOTE_THRESHOLD and current_tier > DifficultyTier.EASY:
		current_tier -= 1

	if current_tier != previous_tier:
		var reason := "promoted" if current_tier > previous_tier else "demoted"
		EventBus.difficulty_adjusted.emit(current_tier, reason)


## Public read for the question-selection system to consult.
func get_current_tier() -> DifficultyTier:
	return current_tier


func _get_save_data() -> Dictionary:
	return {
		"current_tier": current_tier,
		"recent_results": _recent_results,
	}


func _apply_save_data(data: Dictionary) -> void:
	current_tier = data.get("current_tier", DifficultyTier.MEDIUM)
	var loaded: Array = data.get("recent_results", [])
	_recent_results.clear()
	for v in loaded:
		_recent_results.append(bool(v))
