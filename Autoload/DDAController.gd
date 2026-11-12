extends Node
## DDAController (Autoload Singleton)
##
## Applies the completed quest's AQPI to difficulty. Correct answer streaks
## can also promote the tier while the player is answering questions.

enum DifficultyTier { EASY, MEDIUM, HARD }

## IMPLEMENTATION DEFAULT - not specified in the thesis excerpt. "Maximum
## Possible Points" is undefined there for an open-ended point total, so
## this is a configurable ceiling for normalizing P. Tune freely.
@export var max_possible_points: float = 100.0

## PROPOSED thresholds, not official thesis values - see THRESHOLDS note
## above. AQPI below easy_threshold -> EASY. At/above hard_threshold -> HARD.
## Between the two -> MEDIUM.
@export var easy_threshold: float = 0.40
@export var hard_threshold: float = 0.75

## How many consecutive correct answers trigger the separate streak
## promotion rule. See STREAK RULE note above.
@export var streak_length_for_promotion: int = 5

var current_tier: DifficultyTier = DifficultyTier.EASY
var last_aqpi_score: float = 0.0
var _consecutive_correct: int = 0


func _ready() -> void:
	EventBus.question_answered.connect(_on_question_answered)
	EventBus.quest_aqpi_calculated.connect(_apply_quest_aqpi)
	SaveManager.register_section("dda", _get_save_data, _apply_save_data)


func _on_question_answered(_question_id: String, was_correct: bool) -> void:
	_update_streak(was_correct)


func _update_streak(was_correct: bool) -> void:
	if was_correct:
		_consecutive_correct += 1
	else:
		_consecutive_correct = 0
		return

	if _consecutive_correct >= streak_length_for_promotion:
		_consecutive_correct = 0
		if current_tier < DifficultyTier.HARD:
			var previous_tier := current_tier
			current_tier += 1
			EventBus.difficulty_adjusted.emit(current_tier, "streak_promoted")
			push_warning("DDAController: %d-answer streak promoted tier %s -> %s" % [
				streak_length_for_promotion, DifficultyTier.keys()[previous_tier], DifficultyTier.keys()[current_tier]
			])


func _apply_quest_aqpi(_quest_id: String, aqpi: float) -> void:
	last_aqpi_score = aqpi
	var previous_tier := current_tier
	if aqpi < easy_threshold:
		current_tier = DifficultyTier.EASY
	elif aqpi >= hard_threshold:
		current_tier = DifficultyTier.HARD
	else:
		current_tier = DifficultyTier.MEDIUM

	if current_tier != previous_tier:
		var reason := "aqpi_promoted" if current_tier > previous_tier else "aqpi_demoted"
		EventBus.difficulty_adjusted.emit(current_tier, reason)


## Public read for QuestionManager/FishingManager - UNCHANGED usage from
## before this rewrite, still just returns the current tier.
func get_current_tier() -> DifficultyTier:
	return current_tier


func get_last_aqpi_score() -> float:
	return last_aqpi_score


## --- Adaptation 2: Hint Frequency ---
## IMPLEMENTATION DEFAULT mapping (tier -> whether a hint is offered at
## all). EASY players get hints available every time; MEDIUM sometimes
## (every other question); HARD never - assumes higher demonstrated
## mastery needs less scaffolding. Consulted by FishingUI, which shows/
## hides a Hint button accordingly. A question's own "hint" text (see
## README_DDA_SYSTEM.md) is optional JSON content, unrelated to this tier
## check - this only decides whether the OPTION to see it is offered.
var _questions_since_last_hint: int = 0

func should_show_hint() -> bool:
	match current_tier:
		DifficultyTier.EASY:
			return true
		DifficultyTier.MEDIUM:
			_questions_since_last_hint += 1
			if _questions_since_last_hint >= 2:
				_questions_since_last_hint = 0
				return true
			return false
		DifficultyTier.HARD:
			return false
	return false


## --- Adaptation 3: Fish Bite Timing ---
## IMPLEMENTATION DEFAULT ranges (seconds). EASY bites come sooner and
## more predictably (more learning repetitions per session, less
## frustration); HARD bites take longer and are more variable. MEDIUM
## matches the original fixed range this project already used.
func get_bite_wait_range() -> Vector2:
	match current_tier:
		DifficultyTier.EASY:
			return Vector2(1.0, 2.0)
		DifficultyTier.HARD:
			return Vector2(2.5, 6.0)
		_:
			return Vector2(1.5, 4.0)


## --- Adaptation 4: Number of Required Fish ---
## IMPLEMENTATION DEFAULT multipliers applied to a quest's authored
## catch_fish "count" at evaluation time (QuestObjectiveManager applies
## this - the base JSON value is never mutated). EASY reduces the
## requirement, HARD increases it.
func get_required_fish_multiplier() -> float:
	match current_tier:
		DifficultyTier.EASY:
			return 0.5
		DifficultyTier.HARD:
			return 1.5
		_:
			return 1.0


## --- Adaptation 5: Educational Assistance ---
## IMPLEMENTATION DEFAULT interpretation: how much longer (or shorter)
## explanation toasts stay on screen. EASY gets more time/emphasis
## (more scaffolding for a struggling learner); HARD gets less (assumes
## the concept is already understood).
func get_explanation_duration_multiplier() -> float:
	match current_tier:
		DifficultyTier.EASY:
			return 1.5
		DifficultyTier.HARD:
			return 0.7
		_:
			return 1.0


func _get_save_data() -> Dictionary:
	return {
		"current_tier": current_tier,
		"last_aqpi_score": last_aqpi_score,
	}


func _apply_save_data(data: Dictionary) -> void:
	current_tier = data.get("current_tier", DifficultyTier.MEDIUM)
	last_aqpi_score = data.get("last_aqpi_score", 0.0)
	_consecutive_correct = 0
