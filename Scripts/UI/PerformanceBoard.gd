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
##   AccuracyLabel     (Label)   - answer accuracy percentage
##   CorrectLabel      (Label)   - total correct answers
##   IncorrectLabel    (Label)   - main incorrect
##   PointsLabel       (Label)   - earned / deducted details
##   AQPILabel         (Label)   - AQPI 0-100; PointsValue is the net balance
##   TierLabel         (Label)   - current tier name
##   TimeLabel         (Label)   - total time H:MM:SS
##   MiniLabel         (Label)   - mini quests triggered
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
	# Match the newer UI font while retaining the board's local styles and layout.
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	close_button.pressed.connect(_on_close)
	export_button.pressed.connect(_on_export)
	resized.connect(_update_layout)
	_update_layout()
	_populate()


func _notification(what: int) -> void:
	# Visibility notifications can arrive before @onready references exist.
	# _ready() performs the initial population once the child nodes are ready.
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_populate()


func _populate() -> void:
	_fill_summary()
	_fill_regions()
	_fill_exams()
	_fill_quests()


# --- Summary card ---

func _update_layout() -> void:
	%Cards.columns = 1 if size.x < 440 else 2
	get_node("Margin/Panel/Layout/Header/HeaderRow/RecordBadge").visible = size.x >= 440


func _fill_summary() -> void:
	var total: int = PerformanceTracker.total_questions_answered
	var correct: int = PerformanceTracker.total_correct
	var acc: float = PerformanceTracker.get_accuracy()
	accuracy_label.text = "%d%%" % int(acc * 100)
	%AccuracyProgress.value = acc * 100
	%AccuracyDetail.text = "%d of %d answers correct" % [correct, total]
	correct_label.text = str(correct)
	%CorrectDetail.text = "Main: %d · Mini: %d" % [
		PerformanceTracker.total_main_correct, PerformanceTracker.total_mini_correct]
	incorrect_label.text = "Incorrect — Main: %d · Mini: %d" % [
		PerformanceTracker.total_main_incorrect, PerformanceTracker.total_mini_incorrect]
	%PointsValue.text = str(FishingManager.get_points())
	points_label.text = "Earned: %d · Deducted: %d" % [
		PerformanceTracker.total_points_earned, PerformanceTracker.total_points_deducted]
	var quest_aqpi := PerformanceTracker.get_latest_quest_aqpi()
	aqpi_label.text = "—" if quest_aqpi < 0.0 else "%.1f" % (quest_aqpi * 100.0)
	var tier_names := ["EASY", "MEDIUM", "HARD"]
	var tier_idx: int = clampi(int(DDAController.get_current_tier()), 0, 2)
	tier_label.text = tier_names[tier_idx]
	tier_label.add_theme_color_override("font_color", Color("8ed27b") if tier_idx == 0 else Color("e6bd75"))
	var secs := int(PerformanceTracker.total_time_seconds)
	time_label.text = "%02d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]
	mini_label.text = str(PerformanceTracker.total_mini_quests_triggered)


func _clear_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _text(parent: Node, value: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _record_row(container: VBoxContainer, title: String, detail: String, status: String = "", positive: bool = false) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)
	var icon := TextureRect.new()
	var icon_name := "region" if container == region_container else ("exam" if container == exam_container else "journal")
	icon.texture = load("res://Assets/UI/HUDReference/performance-" + icon_name + ".svg")
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	_text(text, title)
	_text(text, detail, 13).add_theme_color_override("font_color", Color("e6bd75"))
	if not status.is_empty():
		var badge := PanelContainer.new()
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253b24") if positive else Color("584536")
		style.set_corner_radius_all(8)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		badge.add_theme_stylebox_override("panel", style)
		row.add_child(badge)
		var label := _text(badge, status, 12)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_color_override("font_color", Color("8ed27b") if positive else Color("f0dec1"))


# --- Region rows ---

func _fill_regions() -> void:
	_clear_rows(region_container)

	# Collect all known region ids from RegionManager's definitions.
	# RegionManager keeps _region_definitions private, so we ask for knowna
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

		_record_row(region_container, name_str,
			region_id.replace("_", " ").capitalize() + (" · Current region" if not current_marker.is_empty() else ""),
			status.to_upper(), unlocked)



# --- Exam rows ---

func _fill_exams() -> void:
	_clear_rows(exam_container)

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
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			exam_container.add_child(row)

	if not any_found:
		_record_row(exam_container, "Exam history", "Your completed regional examinations will appear here.")


# --- Quest rows ---

func _fill_quests() -> void:
	_clear_rows(quest_container)

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
		_record_row(quest_container, display, "Quest record", state.capitalize(), state == "completed")

	if quest_container.get_child_count() == 0:
		_record_row(quest_container, "No quests started yet", "Your quest records will appear here.")


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
	var quest_aqpi := PerformanceTracker.get_latest_quest_aqpi()
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
	if quest_aqpi >= 0.0:
		lines.append("summary,aqpi_quest_id,%s" % PerformanceTracker.latest_scored_quest_id)
		lines.append("summary,aqpi_score,%.2f" % (quest_aqpi * 100.0))
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
