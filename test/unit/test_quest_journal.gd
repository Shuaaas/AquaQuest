extends GutTest
const DATA := preload("res://Scripts/UI/QuestJournalData.gd")
const JOURNAL := preload("res://Scene/UI/QuestJournalUI.tscn")
var saved: Dictionary
var state: int
var screen: Control


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	saved = QuestManager._get_save_data().duplicate(true)
	state = GameManager.current_state
	GameManager.current_state = GameManager.GameState.PLAYING
	QuestManager._apply_save_data({})
	screen = JOURNAL.instantiate()
	add_child(screen)


func after_each() -> void:
	screen.free()
	QuestManager._apply_save_data(saved)
	GameManager.current_state = state
	await get_tree().process_frame


func fixture(status: String, progress: Dictionary) -> void:
	QuestManager._apply_save_data(
		{"quest_states": {"learn_post_harvest_basics": {"state": status, "objectives": progress}}}
	)


func test_empty_journal_owns_and_releases_only_its_pause() -> void:
	assert_true(DATA.quest_ids("active").is_empty())
	assert_true(screen.open_journal())
	assert_true(get_tree().paused)
	screen.close_journal()
	assert_false(get_tree().paused)
	GameManager.set_paused(true)
	assert_false(screen.open_journal())
	screen.close_journal()
	assert_true(get_tree().paused)
	GameManager.set_paused(false)


func test_actual_data_and_no_quest_or_reward_mutation() -> void:
	fixture("active", {"obj_0": 0})
	var before := QuestManager._get_save_data().duplicate(true)
	var inventory := InventoryManager._get_save_data().duplicate(true)
	var data := DATA.details("learn_post_harvest_basics")
	assert_eq(data.title, "Learn the Basics")
	assert_eq(data.giver, "Teacher Ana")
	assert_string_contains(data.reward, "1")
	assert_eq(
		data.objectives[0].target,
		QuestObjectiveManager.get_objective_target_count({"type": "catch_fish", "count": 1})
	)
	assert_true(screen.open_journal("learn_post_harvest_basics"))
	screen._change_tab("completed")
	screen.close_journal()
	assert_eq(QuestManager._get_save_data(), before)
	assert_eq(InventoryManager._get_save_data(), inventory)


func test_ready_and_completed_records_remain_authoritative() -> void:
	fixture("active", {"obj_0": 1, "objectives_complete": true})
	var data := DATA.details("learn_post_harvest_basics")
	assert_eq(data.status, "Ready to turn in")
	assert_eq(data.percent, 100.0)
	assert_eq(data.objectives[0].counter, "1 recorded · Done")
	fixture("completed", {"obj_0": 1})
	assert_eq(DATA.quest_ids("completed"), ["learn_post_harvest_basics"])
	assert_eq(DATA.details("learn_post_harvest_basics").status, "Completed")


func test_phone_navigation_and_escape() -> void:
	fixture("active", {})
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(390, 844)
	assert_true(screen.open_journal())
	screen._layout()
	assert_true(screen.get_node("%Navigation").visible)
	screen._select("learn_post_harvest_basics")
	assert_false(screen.get_node("%Navigation").visible)
	assert_true(screen.get_node("%Paper").visible)
	screen.get_node("%BackButton").pressed.emit()
	assert_true(screen.get_node("%Navigation").visible)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	screen._input(event)
	assert_false(screen.visible)
	assert_false(get_tree().paused)


func test_desktop_panel_settles_inside_screen_after_text_wraps() -> void:
	fixture("active", {})
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1200, 760)
	screen.open_journal("learn_post_harvest_basics")
	for frame in 12:
		await get_tree().process_frame
	var bounds: Rect2 = screen.get_node("%Frame").get_rect()
	assert_true(Rect2(Vector2.ZERO, screen.size).encloses(bounds))
	assert_true(screen.get_node("%Navigation").visible)
	assert_true(screen.get_node("%Paper").visible)
	screen.close_journal()
