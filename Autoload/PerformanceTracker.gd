extends Node
## PerformanceTracker (Autoload Singleton)
##
## Collects every performance metric the Performance Board needs from
## EventBus signals. Owns NO gameplay logic and changes NO game state -
## it is a pure read-only observer that accumulates counters and writes
## them to SaveManager under the "performance" section.
##
## DATA COLLECTED:
##   - Lifetime question totals (correct, incorrect, by type: main / mini)
##   - Per-session time: start timestamp recorded on first question shown
##   - Mini-quest trigger count (reuses the mini_quest_triggered signal -
##     same source DDAController uses for its M term, ensuring consistency)
##   - Points earned / deducted (mirrors DDAController's interpretation:
##     positive deltas = earned, negative = penalty - never counts shop
##     spending as earned, matching DDAController._on_points_changed)
##   - Difficulty tier at the time each question was answered
##
## SESSION vs. LIFETIME: all counters here are LIFETIME (persist across
## save/load). A "session" is implicitly whatever happened since the last
## load, but the Performance Board computes live AQPI from the same
## lifetime totals DDAController uses (its window resets, but the Board
## shows the full career picture). Both are exposed.
##
## SAVE SECTION: "performance" - registered with SaveManager, same pattern
## as every other manager.

var _session_start_msec: int = 0
var _session_started: bool = false

# --- Lifetime question counters ---
var total_questions_answered: int = 0
var total_correct: int = 0
var total_incorrect: int = 0
var total_main_correct: int = 0
var total_main_incorrect: int = 0
var total_mini_correct: int = 0
var total_mini_incorrect: int = 0

# --- Mini-quest stats ---
var total_mini_quests_triggered: int = 0

# --- Points ledger (mirrors FishingManager's fields for cross-check) ---
var total_points_earned: int = 0   # sum of positive point deltas only
var total_points_deducted: int = 0 # sum of negative point deltas (stored as positive)

# --- Time (seconds) ---
var total_time_seconds: float = 0.0  # lifetime cumulative time on questions

# --- Difficulty tier distribution ---
# tier (0/1/2) -> questions answered at that tier
var questions_by_tier: Dictionary = { 0: 0, 1: 0, 2: 0 }

# --- Tracks whether the last question shown was a mini quest ---
var _last_was_mini: bool = false

# --- Time each question was shown (msec) ---
var _question_shown_at_msec: int = 0


func _ready() -> void:
	EventBus.fishing_question_ready.connect(_on_main_question_shown)
	EventBus.mini_quest_question_ready.connect(_on_mini_question_shown)
	EventBus.question_answered.connect(_on_question_answered)
	EventBus.mini_quest_triggered.connect(_on_mini_quest_triggered)
	EventBus.fishing_points_changed.connect(_on_points_changed)
	SaveManager.register_section("performance", _get_save_data, _apply_save_data)


func _on_main_question_shown(_spot_id: String, _question: Dictionary) -> void:
	_last_was_mini = false
	_record_question_start()


func _on_mini_question_shown(_spot_id: String, _question: Dictionary) -> void:
	_last_was_mini = true
	_record_question_start()


func _record_question_start() -> void:
	_question_shown_at_msec = Time.get_ticks_msec()
	if not _session_started:
		_session_start_msec = _question_shown_at_msec
		_session_started = true


func _on_question_answered(_question_id: String, was_correct: bool) -> void:
	var elapsed := (Time.get_ticks_msec() - _question_shown_at_msec) / 1000.0
	total_time_seconds += max(elapsed, 0.0)

	var tier: int = DDAController.get_current_tier()
	if not questions_by_tier.has(tier):
		questions_by_tier[tier] = 0
	questions_by_tier[tier] += 1

	total_questions_answered += 1
	if was_correct:
		total_correct += 1
		if _last_was_mini:
			total_mini_correct += 1
		else:
			total_main_correct += 1
	else:
		total_incorrect += 1
		if _last_was_mini:
			total_mini_incorrect += 1
		else:
			total_main_incorrect += 1


func _on_mini_quest_triggered(_spot_id: String) -> void:
	total_mini_quests_triggered += 1


func _on_points_changed(_new_total: int, delta: int) -> void:
	if delta > 0:
		total_points_earned += delta
	elif delta < 0:
		total_points_deducted += -delta  # store as positive


# --- Public getters for PerformanceBoard ---

func get_accuracy() -> float:
	if total_questions_answered == 0:
		return 0.0
	return float(total_correct) / float(total_questions_answered)


## AQPI using the thesis formula over lifetime totals.
## A = correct / total
## T = 1 - (time_used / 600)
## M = 1 - (mini_quests_triggered / total_questions)
## P = earned_points / max_possible_points
## Returns a value in [0.0, 1.0].
func compute_aqpi() -> float:
	var a := clampf(get_accuracy(), 0.0, 1.0)
	var t := clampf(1.0 - (total_time_seconds / DDAController.MAX_TIME_SECONDS), 0.0, 1.0)
	var m := 1.0
	if total_questions_answered > 0:
		m = clampf(1.0 - (float(total_mini_quests_triggered) / float(total_questions_answered)), 0.0, 1.0)
	var p := clampf(
		float(total_points_earned) / maxf(float(DDAController.max_possible_points), 1.0),
		0.0, 1.0
	)
	return (0.40 * a) + (0.20 * t) + (0.20 * m) + (0.20 * p)


func get_session_time_seconds() -> float:
	if not _session_started:
		return 0.0
	return (Time.get_ticks_msec() - _session_start_msec) / 1000.0


# --- Save / Load ---

func _get_save_data() -> Dictionary:
	return {
		"total_questions_answered": total_questions_answered,
		"total_correct": total_correct,
		"total_incorrect": total_incorrect,
		"total_main_correct": total_main_correct,
		"total_main_incorrect": total_main_incorrect,
		"total_mini_correct": total_mini_correct,
		"total_mini_incorrect": total_mini_incorrect,
		"total_mini_quests_triggered": total_mini_quests_triggered,
		"total_points_earned": total_points_earned,
		"total_points_deducted": total_points_deducted,
		"total_time_seconds": total_time_seconds,
		"questions_by_tier": questions_by_tier,
	}


func _apply_save_data(data: Dictionary) -> void:
	total_questions_answered = int(data.get("total_questions_answered", 0))
	total_correct            = int(data.get("total_correct", 0))
	total_incorrect          = int(data.get("total_incorrect", 0))
	total_main_correct       = int(data.get("total_main_correct", 0))
	total_main_incorrect     = int(data.get("total_main_incorrect", 0))
	total_mini_correct       = int(data.get("total_mini_correct", 0))
	total_mini_incorrect     = int(data.get("total_mini_incorrect", 0))
	total_mini_quests_triggered = int(data.get("total_mini_quests_triggered", 0))
	total_points_earned      = int(data.get("total_points_earned", 0))
	total_points_deducted    = int(data.get("total_points_deducted", 0))
	total_time_seconds       = float(data.get("total_time_seconds", 0.0))
	# Normalize tier keys back to ints (JSON round-trips them as strings).
	var raw_tiers = data.get("questions_by_tier", {})
	questions_by_tier = { 0: 0, 1: 0, 2: 0 }
	for k in raw_tiers:
		questions_by_tier[int(k)] = int(raw_tiers[k])
