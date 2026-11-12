extends Node
## PerformanceTracker (Autoload Singleton)
##
## Collects every performance metric the Performance Board needs from
## EventBus signals. Owns NO gameplay logic and changes NO game state -
## it is a pure read-only observer that accumulates counters and writes
## them to SaveManager under the "performance" section.
##
## Lifetime stats are saved separately from each quest's AQPI.

const FULL_TIME_CREDIT_SECONDS := 120.0
const ZERO_TIME_CREDIT_SECONDS := 600.0

var _quest_baselines: Dictionary = {}
var quest_aqpi_scores: Dictionary = {}
var latest_scored_quest_id: String = ""

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
	EventBus.exam_question_ready.connect(_on_exam_question_shown)
	EventBus.question_answered.connect(_on_question_answered)
	EventBus.mini_quest_triggered.connect(_on_mini_quest_triggered)
	EventBus.fishing_points_changed.connect(_on_points_changed)
	EventBus.quest_started.connect(_on_quest_started)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_failed.connect(_on_quest_failed)
	SaveManager.register_section("performance", _get_save_data, _apply_save_data, true)


func _on_main_question_shown(_spot_id: String, _question: Dictionary) -> void:
	_last_was_mini = false
	_record_question_start()


func _on_exam_question_shown(_exam_id: String, _number: int, _total: int, _question: Dictionary) -> void:
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


func _quest_totals() -> Dictionary:
	return {
		"answers": total_questions_answered,
		"correct": total_correct,
		"seconds": total_time_seconds,
		"mini": total_mini_quests_triggered,
		"points": total_points_earned,
	}


func _on_quest_started(quest_id: String) -> void:
	var definition := QuestObjectiveManager.get_quest_definition(quest_id)
	for objective in definition.get("objectives", []):
		if objective.get("type") in ["catch_fish", "answer_questions", "pass_exam"]:
			_quest_baselines[quest_id] = _quest_totals()
			return


func _on_quest_completed(quest_id: String) -> void:
	if not _quest_baselines.has(quest_id):
		return
	var baseline: Dictionary = _quest_baselines[quest_id]
	_quest_baselines.erase(quest_id)
	var answers := total_questions_answered - int(baseline.answers)
	if answers <= 0:
		return

	var accuracy := clampf(float(total_correct - int(baseline.correct)) / answers, 0.0, 1.0)
	var seconds := total_time_seconds - float(baseline.seconds)
	var time_efficiency := clampf(
		(ZERO_TIME_CREDIT_SECONDS - seconds) / (ZERO_TIME_CREDIT_SECONDS - FULL_TIME_CREDIT_SECONDS),
		0.0, 1.0
	)
	var independence := clampf(1.0 - float(total_mini_quests_triggered - int(baseline.mini)) / answers, 0.0, 1.0)
	var earned := total_points_earned - int(baseline.points)
	var points := clampf(earned / maxf(DDAController.max_possible_points, 1.0), 0.0, 1.0)
	var score := 0.40 * accuracy + 0.20 * time_efficiency + 0.20 * independence + 0.20 * points
	quest_aqpi_scores[quest_id] = score
	latest_scored_quest_id = quest_id
	EventBus.quest_aqpi_calculated.emit(quest_id, score)


func _on_quest_failed(quest_id: String) -> void:
	_quest_baselines.erase(quest_id)


func get_latest_quest_aqpi() -> float:
	return float(quest_aqpi_scores.get(latest_scored_quest_id, -1.0))


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
		"quest_baselines": _quest_baselines.duplicate(true),
		"quest_aqpi_scores": quest_aqpi_scores.duplicate(),
		"latest_scored_quest_id": latest_scored_quest_id,
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
	_quest_baselines = data.get("quest_baselines", {}).duplicate(true)
	quest_aqpi_scores = data.get("quest_aqpi_scores", {}).duplicate()
	latest_scored_quest_id = data.get("latest_scored_quest_id", "")
	# Older saves have lifetime totals but no record of when an active quest began.
	for quest_id in QuestObjectiveManager.get_quest_definitions():
		if QuestManager.get_quest_state(quest_id) == "active" and not _quest_baselines.has(quest_id):
			_on_quest_started(quest_id)
