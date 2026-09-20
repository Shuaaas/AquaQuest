extends Node
## DDAController (Autoload Singleton)
##
## AQPI-based Dynamic Difficulty Adjustment engine. Monitors player
## performance (accuracy, response time, mini quest frequency, points
## earned) and computes the official AQPI score from the thesis formula,
## which determines the current difficulty tier. It also exposes five
## adaptation getters that other systems consult to personalize the
## educational experience - it never touches player movement, input,
## collision, or exploration in any way (confirmed by direct code search
## before this rewrite - this file has zero references to those systems,
## and this rewrite adds none).
##
## ============================================================
## OFFICIAL AQPI FORMULA (per thesis, do not alter the weights):
##   AQPI = 0.40*A + 0.20*T + 0.20*M + 0.20*P
##   A (Accuracy)         = Correct Answers / Total Questions
##   T (Time Efficiency)  = 1 - (Time Used / Maximum Time)
##   M (Mini Quest Dep.)  = 1 - (Mini Quests Triggered / Total Questions)
##   P (Points Perf.)     = Earned Points / Maximum Possible Points
## All four terms clamped to [0.0, 1.0] before combining, per the thesis'
## own normalization requirement.
## ============================================================
##
## EVALUATION WINDOW (implementation decision, NOT part of the formula
## itself): AQPI is recalculated every EVALUATION_WINDOW_SIZE answered
## questions, using only data from that window, then counters reset for
## the next window. The thesis formula's terms (Correct Answers/Total
## Questions/etc.) don't specify a time scope on their own - a purely
## lifetime-cumulative total would make AQPI less and less responsive as
## a session goes on, which would undermine "dynamic" adjustment. Scoping
## to a periodic window is a standard, reasonable choice for this kind of
## system and does NOT change the formula's math - only how often and
## over what data it's evaluated. This is clearly separated from the
## formula itself so it's obvious what's official vs. implementation.
##
## THRESHOLDS ARE IMPLEMENTATION DEFAULTS, NOT OFFICIAL THESIS VALUES -
## the source material explicitly states exact AQPI-to-tier cutoffs
## weren't provided. easy_threshold/hard_threshold below are proposed
## starting points, exported so they can be tuned once your adviser
## confirms official cutoffs, per your own instruction not to invent and
## present thresholds as official.
##
## STREAK RULE (separate from AQPI, per your thesis flowchart note): the
## PREVIOUS implementation here was a 5-ANSWER ROLLING WINDOW requiring
## 80% accuracy (4-5 correct out of the last 5, not necessarily
## consecutive) - this was never a "streak" in the true sense, and is now
## retired in favor of AQPI as the primary tier mechanism. A genuine
## 5-CONSECUTIVE-correct streak (resetting to 0 on any wrong answer) is
## implemented separately below as its own, additional promotion trigger,
## independent of AQPI's periodic recalculation - see _consecutive_correct.
## Its exact behavior (instant single-tier promotion, capped at HARD) is
## an implementation default, not verified thesis content - flagged
## explicitly per your instruction.
##
## ADAPTATION OUTPUTS (the 5 things this system personalizes):
##   1. Question Difficulty  -> get_current_tier(), already consumed by
##      FishingManager/QuestionManager exactly as before this rewrite
##   2. Hint Frequency       -> should_show_hint(), consulted by FishingUI
##   3. Fish Bite Timing     -> get_bite_wait_range(), consulted by
##      FishingManager instead of its own fixed constants
##   4. Required Fish Count  -> get_required_fish_multiplier(), consulted
##      by QuestObjectiveManager when checking catch_fish objectives
##   5. Educational Assistance -> get_explanation_duration_multiplier(),
##      consulted by FishingUI/FishingManager wherever explanation toast
##      duration is computed
## See README_DDA_SYSTEM.md for the full explanation of each.

enum DifficultyTier { EASY, MEDIUM, HARD }

const MAX_TIME_SECONDS := 600.0  # "Maximum Time = 10 minutes" - given exactly by the thesis

## IMPLEMENTATION DEFAULT - not specified in the thesis excerpt. "Maximum
## Possible Points" is undefined there for an open-ended point total, so
## this is a configurable ceiling for normalizing P. Tune freely.
@export var max_possible_points: float = 100.0

## How many answered questions (main + mini quest combined) between each
## AQPI recalculation. See EVALUATION WINDOW note above.
@export var evaluation_window_size: int = 3
#10

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

# --- Evaluation window counters (reset every evaluation_window_size questions) ---
var _correct_count: int = 0
var _total_count: int = 0
var _time_used_sum: float = 0.0
var _mini_quests_triggered: int = 0
var _earned_points_sum: float = 0.0

# --- Streak tracking (independent of the window above) ---
var _consecutive_correct: int = 0

# --- Response time tracking ---
var _question_shown_at_msec: int = 0


func _ready() -> void:
	EventBus.question_answered.connect(_on_question_answered)
	EventBus.fishing_question_ready.connect(_on_question_shown)
	EventBus.mini_quest_question_ready.connect(_on_mini_question_shown)
	EventBus.fishing_points_changed.connect(_on_points_changed)
	SaveManager.register_section("dda", _get_save_data, _apply_save_data)


func _on_question_shown(_spot_id: String, _question: Dictionary) -> void:
	_question_shown_at_msec = Time.get_ticks_msec()


func _on_mini_question_shown(_spot_id: String, _question: Dictionary) -> void:
	_question_shown_at_msec = Time.get_ticks_msec()
	# A Mini Quest only ever begins after a wrong main answer - this IS the
	# "Mini Quests Triggered" event the M term counts. Counted here rather
	# than in FishingManager so all AQPI bookkeeping stays in one place.
	_mini_quests_triggered += 1


func _on_points_changed(_new_total: int, delta: int) -> void:
	# "Earned Points" is interpreted as points GAINED, not net score - a
	# wrong-answer deduction isn't something the player "earned," so only
	# positive deltas accumulate here. This is an interpretation of an
	# ambiguous term in the thesis excerpt, flagged explicitly rather than
	# silently assumed.
	if delta > 0:
		_earned_points_sum += delta


func _on_question_answered(_question_id: String, was_correct: bool) -> void:
	var elapsed_seconds := (Time.get_ticks_msec() - _question_shown_at_msec) / 1000.0
	_time_used_sum += max(elapsed_seconds, 0.0)

	_total_count += 1
	if was_correct:
		_correct_count += 1

	_update_streak(was_correct)

	if _total_count >= evaluation_window_size:
		_evaluate_aqpi()


## Independent of AQPI - see STREAK RULE note in the class doc above.
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


## Computes AQPI from this window's accumulated data using the OFFICIAL
## formula (weights are NOT configurable - only the window size and
## tier thresholds are, per the thesis' own distinction between the
## formula and its as-yet-unofficial thresholds).
func _evaluate_aqpi() -> void:
	var a: float = clampf(float(_correct_count) / float(_total_count), 0.0, 1.0)
	var t: float = clampf(1.0 - (_time_used_sum / MAX_TIME_SECONDS), 0.0, 1.0)
	var m: float = clampf(1.0 - (float(_mini_quests_triggered) / float(_total_count)), 0.0, 1.0)
	var p: float = clampf(_earned_points_sum / max_possible_points, 0.0, 1.0)

	var aqpi: float = (0.40 * a) + (0.20 * t) + (0.20 * m) + (0.20 * p)
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
	
	print("AQPI: ", aqpi, " (A=", a, " T=", t, " M=", m, " P=", p, ") -> tier: ", DifficultyTier.keys()[current_tier])
	_reset_window()


func _reset_window() -> void:
	_correct_count = 0
	_total_count = 0
	_time_used_sum = 0.0
	_mini_quests_triggered = 0
	_earned_points_sum = 0.0


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
	current_tier = data.get("current_tier", DifficultyTier.EASY)
	last_aqpi_score = data.get("last_aqpi_score", 0.0)
	# Evaluation-window counters and the consecutive streak intentionally
	# do NOT persist across save/load - they reset fresh each session,
	# rather than resuming a partially-completed window from a previous
	# play session. Only the resulting tier and last computed score persist.
	_reset_window()
	_consecutive_correct = 0
