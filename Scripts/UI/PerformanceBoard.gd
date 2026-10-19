extends Control
class_name PerformanceBoard
## PerformanceBoard
##
## Reads performance data exclusively from PerformanceTracker, FishingManager,
## ExamManager, QuestManager, and RegionManager - it NEVER awards points,
## changes DDA, modifies quest state, or triggers mini quests.
## Opens via KEY_P (wired in main.gd) or from a UI button.
##
## LAYOUT (all nodes must be marked "Access as Unique Name" in the scene):
##   CloseButton       (Button)
##   ExportButton      (Button)
##   AccuracyLabel     (Label)   - "XX% (C/T)"
##   CorrectLabel      (Label)   - main correct / total
##   IncorrectLabel    (Label)   - main incorrect
##   PointsLabel       (Label)   - current net balance
##   AQPILabel         (Label)   - AQPI 0-100
##   TierLabel         (Label)   - current tier name
##   TimeLabel         (Label)   - total time H:MM:SS
##   MiniLabel         (Label)   - triggered / correct / wrong
##   RegionContainer   (VBoxContainer) - region rows added dynamically
##   ExamContainer     (VBoxContainer) - exam rows added dynamically
##   QuestContainer    (VBoxContainer) - quest rows added dynamically

@onready var close_button: Button          = %CloseButton
@onready var export_button: Button         = %ExportButton
@onready var accuracy_label: Label         = %AccuracyLabel
@onready var correct_label: Label          = %CorrectLabel
@onready var incorrect_label: Label        = %IncorrectLabel
@onready var points_label: Label           = %PointsLabel
@onready var aqpi_label: Label             = %AQPILabel
@onready var tier_label: Label             = %TierLabel
@onready var time_label: Label             = %TimeLabel
@onready var mini_label: Label             = %MiniLabel
@onready var region_container: VBoxContainer  = %RegionContainer
@onready var exam_container: VBoxContainer    = %ExamContainer
@onready var quest_container: VBoxContainer   = %QuestContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_on_close)
	export_button.pressed.connect(_on_export)
	_populate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_populate()


func _populate() -> void:
	_fill_summary()
	_fill_regions()
	_fill_exams()
	_fill_quests()


# --- Summary card ---

func _fill_summary() -> void:
	var total: int = PerformanceTracker.total_questions_answered
	var correct: int = PerformanceTracker.total_correct
	var incorrect: int = PerformanceTracker.total_incorrect
	var acc: float = PerformanceTracker.get_accuracy()

	accuracy_label.text  = "%d%% (%d / %d)" % [int(acc * 100), correct, total]
	correct_label.text   = "Main ✓ %d  Mini ✓ %d" % [
		PerformanceTracker.total_main_correct,
		PerformanceTracker.total_mini_correct,
	]
	incorrect_label.text = "Main ✗ %d  Mini ✗ %d" % [
		PerformanceTracker.total_main_incorrect,
		PerformanceTracker.total_mini_incorrect,
	]
	points_label.text    = "Net Points: %d  (Earned: %d  Deducted: %d)" % [
		FishingManager.get_points(),
		PerformanceTracker.total_points_earned,
		PerformanceTracker.total_points_deducted,
	]

	var aqpi_raw: float = PerformanceTracker.compute_aqpi()
	aqpi_label.text = "AQPI: %.1f / 100" % (aqpi_raw * 100.0)

	var tier_names := ["Easy", "Medium", "Hard"]
	var tier_idx: int = clamp(int(DDAController.get_current_tier()), 0, 2)
	tier_label.text = "Current Difficulty: %s" % tier_names[tier_idx]

	var secs := int(PerformanceTracker.total_time_seconds)
	time_label.text = "Total Question Time: %d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]

	mini_label.text = "Mini Quests — Triggered: %d  Correct: %d  Wrong: %d" % [
		PerformanceTracker.total_mini_quests_triggered,
		PerformanceTracker.total_mini_correct,
		PerformanceTracker.total_mini_incorrect,
	]


# --- Region rows ---

func _fill_regions() -> void:
	for child in region_container.get_children():
		child.queue_free()

	# Collect all known region ids from RegionManager's definitions.
	# RegionManager keeps _region_definitions private, so we ask for known
	# ids by iterating the exam history and quest data instead, then fall
	# back to the two we know exist from the JSON files.
	var known_region_ids: Array = ["region_1", "region_2",
		"region_3", "region_4", "region_5"]

	for region_id in known_region_ids:
		var def: Dictionary = RegionManager.get_region_definition(region_id)
		if def.is_empty():
			continue  # region not in JSON yet - skip silently

		var name_str: String = def.get("name", region_id)
		var unlocked: bool   = RegionManager.is_region_unlocked(region_id)
		var status: String   = "Unlocked" if unlocked else "Locked"
		var current_marker   = " ← Current" if region_id == RegionManager.current_region_id else ""

		var row := Label.new()
		row.text = "%s — %s%s" % [name_str, status, current_marker]
		region_container.add_child(row)


# --- Exam rows ---

func _fill_exams() -> void:
	for child in exam_container.get_children():
		child.queue_free()

	# Exam ids we know about; extend this list as more are added.
	var known_exam_ids: Array = ["region1_exam", "region2_exam",
		"region3_exam", "region4_exam", "region5_exam"]

	var any_found := false
	for exam_id in known_exam_ids:
		var history: Array = ExamManager.get_exam_history(exam_id)
		if history.is_empty():
			continue
		any_found = true

		var header := Label.new()
		header.text = "— %s —" % exam_id.replace("_", " ").capitalize()
		exam_container.add_child(header)

		for i in range(history.size()):
			var attempt: Dictionary = history[i]
			var score_pct: int = int(attempt.get("score", 0.0) * 100)
			var passed: bool   = attempt.get("passed", false)
			var correct: int   = int(attempt.get("correct_count", 0))
			var total: int     = int(attempt.get("total_questions", 0))
			var ts: int        = int(attempt.get("timestamp", 0))
			var dt: String     = Time.get_datetime_string_from_unix_time(ts) if ts > 0 else "?"
			var result: String = "PASS" if passed else "FAIL"

			var row := Label.new()
			row.text = "  Attempt %d: %s  %d%%  (%d/%d)  %s" % [
				i + 1, result, score_pct, correct, total, dt
			]
			exam_container.add_child(row)

	if not any_found:
		var none_label := Label.new()
		none_label.text = "(No exam attempts recorded yet)"
		exam_container.add_child(none_label)


# --- Quest rows ---

func _fill_quests() -> void:
	for child in quest_container.get_children():
		child.queue_free()

	# We enumerate all tracked quest ids from QuestManager's internal dict.
	# QuestManager has no public "get all quest ids", so we access the
	# public state getter and call get_quest_state per known id.
	# The authoritative list comes from the JSON files we know exist.
	var known_quest_ids: Array = [
		"learn_post_harvest_basics",
		"visit_region2_mini",
	]

	for quest_id in known_quest_ids:
		var state: String = QuestManager.get_quest_state(quest_id)
		if state == "unknown":
			continue  # not yet started - omit from board

		var display: String = quest_id.replace("_", " ").capitalize()
		var row := Label.new()
		row.text = "%s — %s" % [display, state.capitalize()]
		quest_container.add_child(row)

	if quest_container.get_child_count() == 0:
		var none_label := Label.new()
		none_label.text = "(No quests started yet)"
		quest_container.add_child(none_label)


# --- Close ---

func _on_close() -> void:
	visible = false


# --- CSV Export ---

func _on_export() -> void:
	var lines: Array[String] = []

	# Header
	lines.append("section,key,value")

	# Summary
	var total: int  = PerformanceTracker.total_questions_answered
	var correct: int = PerformanceTracker.total_correct
	var acc_pct: float = PerformanceTracker.get_accuracy() * 100.0
	var aqpi_score: float = PerformanceTracker.compute_aqpi() * 100.0
	var secs: int = int(PerformanceTracker.total_time_seconds)

	lines.append("summary,total_questions,%d" % total)
	lines.append("summary,total_correct,%d" % correct)
	lines.append("summary,total_incorrect,%d" % PerformanceTracker.total_incorrect)
	lines.append("summary,main_correct,%d" % PerformanceTracker.total_main_correct)
	lines.append("summary,main_incorrect,%d" % PerformanceTracker.total_main_incorrect)
	lines.append("summary,mini_correct,%d" % PerformanceTracker.total_mini_correct)
	lines.append("summary,mini_incorrect,%d" % PerformanceTracker.total_mini_incorrect)
	lines.append("summary,accuracy_pct,%.2f" % acc_pct)
	lines.append("summary,total_time_seconds,%d" % secs)
	lines.append("summary,mini_quests_triggered,%d" % PerformanceTracker.total_mini_quests_triggered)
	lines.append("summary,points_earned,%d" % PerformanceTracker.total_points_earned)
	lines.append("summary,points_deducted,%d" % PerformanceTracker.total_points_deducted)
	lines.append("summary,net_points,%d" % FishingManager.get_points())
	lines.append("summary,aqpi_score,%.2f" % aqpi_score)
	lines.append("summary,difficulty_tier,%d" % DDAController.get_current_tier())

	# Tier breakdown
	for tier in [0, 1, 2]:
		lines.append("tier_questions,tier_%d,%d" % [
			tier, PerformanceTracker.questions_by_tier.get(tier, 0)
		])

	# Regions
	var all_region_ids: Array = ["region_1","region_2","region_3","region_4","region_5"]
	for region_id in all_region_ids:
		var def: Dictionary = RegionManager.get_region_definition(region_id)
		if def.is_empty():
			continue
		var unlocked: bool = RegionManager.is_region_unlocked(region_id)
		lines.append("region,%s,%s" % [region_id, "unlocked" if unlocked else "locked"])

	# Exams
	var all_exam_ids: Array = ["region1_exam","region2_exam","region3_exam","region4_exam","region5_exam"]
	for exam_id in all_exam_ids:
		var history: Array = ExamManager.get_exam_history(exam_id)
		for i in range(history.size()):
			var a: Dictionary = history[i]
			lines.append("exam,%s_attempt_%d_score,%.4f" % [exam_id, i + 1, float(a.get("score", 0.0))])
			lines.append("exam,%s_attempt_%d_passed,%s" % [exam_id, i + 1, str(bool(a.get("passed", false)))])
			lines.append("exam,%s_attempt_%d_correct,%d" % [exam_id, i + 1, int(a.get("correct_count", 0))])
			lines.append("exam,%s_attempt_%d_total,%d" % [exam_id, i + 1, int(a.get("total_questions", 0))])
			lines.append("exam,%s_attempt_%d_timestamp,%d" % [exam_id, i + 1, int(a.get("timestamp", 0))])

	# Write to user directory
	var timestamp_str: String = str(int(Time.get_unix_time_from_system()))
	var export_path: String = "user://aquaquest_performance_%s.csv" % timestamp_str
	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		UIManager.show_notification("Export failed: could not write file.", 3.0)
		return

	for line in lines:
		file.store_line(line)
	file.close()

	# Show the absolute path so the player knows where it landed.
	var abs_path: String = ProjectSettings.globalize_path(export_path)
	UIManager.show_notification("Exported to:\n%s" % abs_path, 5.0)
