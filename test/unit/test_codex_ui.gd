extends GutTest

const CODEX_SCENE := preload("res://Scene/UI/CodexUI.tscn")
const INVENTORY_SCENE := preload("res://Scene/UI/inventory_ui.tscn")

var ui: Control
var original_progress: Dictionary
var original_state: int
var original_viewport_size: Vector2i


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original_progress = CodexManager._get_save_data().duplicate(true)
	original_state = GameManager.current_state
	original_viewport_size = get_tree().root.size
	GameManager.current_state = GameManager.GameState.PLAYING
	ui = CODEX_SCENE.instantiate()
	add_child(ui)
	CodexManager._apply_save_data({})


func after_each() -> void:
	ui.close_codex()
	ui.free()
	CodexManager._apply_save_data(original_progress)
	GameManager.current_state = original_state
	get_tree().paused = false
	GameManager.is_paused = false
	get_tree().root.size = original_viewport_size
	# Navigation replaces controls with queue_free; allow their cleanup to finish.
	await get_tree().process_frame


func _text() -> String:
	var parts := PackedStringArray()
	for child in ui.content.get_children():
		if child is RichTextLabel:
			parts.append(child.text)
	return "\n".join(parts)


func test_inventory_button_opens_one_persistent_reader_and_close_restores_game() -> void:
	var inventory := INVENTORY_SCENE.instantiate()
	add_child_autofree(inventory)
	inventory.get_node("%CodexButton").pressed.emit()
	assert_true(ui.visible)
	assert_true(get_tree().paused)
	var child_count := get_child_count()
	EventBus.codex_open_requested.emit()
	assert_eq(get_child_count(), child_count)
	ui.close_button.pressed.emit()
	assert_false(ui.visible)
	assert_false(get_tree().paused)
	assert_true(ui.open_codex())
	ui.close_codex()
	assert_false(GameManager.is_paused)


func test_module_selection_and_locked_clicks_never_reveal_lesson_content() -> void:
	assert_true(ui.open_codex())
	assert_eq(ui.module_list.item_count, 5)
	ui.module_list.item_selected.emit(2)
	assert_eq(ui.lesson_list.get_child_count(), 7)
	ui.lesson_list.get_child(1).pressed.emit()
	assert_true(_text().contains("Locked:"))
	var lesson := CodexManager.get_lesson("module_3_lesson_2")
	assert_false(_text().contains(lesson["summary"]))
	assert_false(CodexManager.is_lesson_unlocked(lesson["id"]))


func test_unlocked_text_definitions_images_and_references_are_rendered() -> void:
	CodexManager._apply_save_data({"unlocked_lesson_ids": ["module_3_lesson_5"]})
	assert_true(ui.open_codex())
	ui.show_module("module_3")
	ui.show_lesson("module_3_lesson_5")
	var text := _text()
	assert_true(text.contains("Key concepts"))
	assert_true(text.contains("Source pages: 3"))
	assert_true(text.contains("Espejo-Hermes"))
	assert_true(text.contains("Self-breakdown"))
	assert_eq(ui._pictures.size(), 1)
	for child in ui.content.get_children():
		if child is RichTextLabel:
			assert_false(child.bbcode_enabled)


func test_region_one_unlock_makes_module_two_readable_in_the_open_codex() -> void:
	var previous_regions: Dictionary = RegionManager._unlocked_regions.duplicate()
	RegionManager._unlocked_regions = {}
	assert_true(ui.open_codex())
	ui.show_module("module_2")
	assert_true(_text().contains("Locked:"))
	RegionManager.unlock_region("region_1")
	var lesson := CodexManager.get_lesson("module_2_lesson_1")
	assert_true(_text().contains(lesson["summary"]))
	assert_false(_text().contains("Locked:"))
	RegionManager._unlocked_regions = previous_regions


func test_missing_image_keeps_text_and_shows_a_readable_placeholder() -> void:
	CodexManager._apply_save_data({"unlocked_lesson_ids": ["module_1_lesson_1"]})
	assert_true(ui.open_codex())
	ui.show_lesson("module_1_lesson_1")
	var before := _text()
	ui._add_picture({"path": "res://Assets/Codex/no_such_image.png", "caption": "Test image"})
	assert_true(_text().begins_with(before))
	assert_true(_text().contains("Illustration unavailable: Test image"))


func test_unlocked_table_remains_readable_as_text() -> void:
	CodexManager._apply_save_data({"unlocked_lesson_ids": ["module_3_lesson_7"]})
	assert_true(ui.open_codex())
	ui.show_module("module_3")
	ui.show_lesson("module_3_lesson_7")
	assert_true(_text().contains("Fresh fish: Bright red"))
	assert_true(_text().contains("Stale fish: Light pink"))


func test_reader_refuses_existing_pause_and_active_dialogue_without_releasing_them() -> void:
	get_tree().paused = true
	assert_false(ui.open_codex())
	ui.close_codex()
	assert_true(get_tree().paused)
	get_tree().paused = false
	var was_active := DialogueManager.is_active
	DialogueManager.is_active = true
	assert_false(ui.open_codex())
	assert_false(get_tree().paused)
	DialogueManager.is_active = was_active


func test_escape_closes_and_freeing_an_open_reader_releases_its_pause() -> void:
	assert_true(ui.open_codex())
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	ui._input(escape)
	assert_false(ui.visible)
	assert_false(get_tree().paused)
	assert_true(ui.open_codex())
	remove_child(ui)
	assert_false(get_tree().paused)


func test_fishing_and_load_transitions_cannot_be_interrupted() -> void:
	var fishing_state: int = FishingManager._state
	FishingManager._state = FishingManager.FlowState.CASTING
	assert_false(ui.open_codex())
	FishingManager._state = fishing_state
	SaveManager.is_loading = true
	assert_false(ui.open_codex())
	SaveManager.is_loading = false
	assert_false(ui.visible)


func test_reader_adapts_to_portrait_and_landscape_without_hiding_close() -> void:
	assert_true(ui.open_codex())
	for viewport_size in [Vector2i(390, 844), Vector2i(720, 360)]:
		get_tree().root.size = viewport_size
		for frame in range(4):
			await get_tree().process_frame
		assert_eq(ui.columns.vertical, viewport_size.x < viewport_size.y)
		assert_gt(ui.content_scroll.size.x, 180.0)
		assert_gt(ui.content_scroll.size.y, 120.0)
		assert_gte(ui.close_button.size.y, 48.0)
		assert_lte(ui.close_button.get_global_rect().end.x, float(viewport_size.x))
		assert_lte(ui.close_button.get_global_rect().end.y, float(viewport_size.y))
