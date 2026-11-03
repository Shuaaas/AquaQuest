extends GutTest

const HUD := preload("res://Scene/UI/GameplayHUD.tscn")
const STATUS := preload("res://Scripts/UI/HUDStatus.gd")
const REGION := preload("res://test/fixtures/save_region.tscn")
var ui_root: Control
var hud: Control
var mini: Control
var journal: Control
var board: Control
var inventory: Control
var codex: Control
var world: Control
var container: Node2D
var player: Player
var original: Dictionary
var sections: Array[Dictionary]


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = {
		"definitions": RegionManager._region_definitions.duplicate(true),
		"region": RegionManager.current_region_id,
		"spawn": RegionManager.pending_spawn_id,
		"inventory": InventoryManager._get_save_data().duplicate(true),
		"quests": QuestManager._get_save_data().duplicate(true),
		"points": FishingManager._get_points_save_data().duplicate(true),
		"tier": DDAController.current_tier,
		"state": GameManager.current_state,
	}
	sections = SaveManager._registered_sections.duplicate()
	RegionManager._region_definitions["gut_hud_region"] = {
		"scene_path": REGION.resource_path, "name": "Test Coast"
	}
	RegionManager.current_region_id = "gut_hud_region"
	RegionManager.pending_spawn_id = "default"
	GameManager.current_state = GameManager.GameState.PLAYING
	InventoryManager._apply_save_data({})
	QuestManager._apply_save_data({})
	container = Node2D.new()
	add_child(container)
	container.add_to_group("region_container")
	var region := REGION.instantiate()
	container.add_child(region)
	player = region.get_node("player")
	ui_root = Control.new()
	ui_root.size = Vector2(1200, 760)
	add_child(ui_root)
	mini = _screen("res://Scene/UI/MiniMapUI.tscn", "MiniMapUI", false)
	inventory = _screen("res://Scene/UI/inventory_ui.tscn", "InventoryUI")
	board = _screen("res://Scene/UI/performance_board.tscn", "PerformanceBoard")
	board.hide()
	codex = _screen("res://Scene/UI/CodexUI.tscn", "CodexUI")
	world = _screen("res://Scene/UI/WorldMapUI.tscn", "WorldMapUI")
	journal = _screen("res://Scene/UI/QuestJournalUI.tscn", "QuestJournalUI")
	hud = HUD.instantiate()
	ui_root.add_child(hud)
	await get_tree().process_frame


func _screen(path: String, name_text: String, overlay: bool = true) -> Control:
	var screen = load(path).instantiate()
	screen.name = name_text
	if name_text == "PerformanceBoard":
		screen.hide()
	ui_root.add_child(screen)
	if overlay:
		screen.add_to_group("gameplay_overlay")
	return screen


func after_each() -> void:
	GameManager.set_paused(false)
	ui_root.free()
	container.free()
	SaveManager._registered_sections = sections
	RegionManager._region_definitions = original.definitions
	RegionManager.current_region_id = original.region
	RegionManager.pending_spawn_id = original.spawn
	InventoryManager._apply_save_data(original.inventory)
	QuestManager._apply_save_data(original.quests)
	FishingManager._apply_points_save_data(original.points)
	DDAController.current_tier = original.tier
	GameManager.current_state = original.state
	await get_tree().process_frame


func test_points_are_the_real_spendable_balance_without_exp_or_level() -> void:
	FishingManager._apply_points_save_data({"points": 300, "total_earned": 500, "total_spent": 200})
	hud.refresh()
	assert_eq(hud.points_label.text, "Points: 300")
	assert_eq(hud.region_label.text, "Test Coast")
	assert_false(STATUS.snapshot().has("level"))
	assert_false(STATUS.snapshot().has("exp"))
	assert_true(FishingManager.spend_points(20))
	hud.refresh()
	assert_eq(hud.points_label.text, "Points: 280")


func test_badge_tracks_equipped_rod_not_merely_owned_item() -> void:
	InventoryManager.add_item("fishing_rod")
	hud.refresh()
	assert_eq(hud.equipment_label.text, "Equip a rod")
	assert_null(hud.equipment_icon.texture)
	player.fishing_rod.toggle()
	hud.refresh()
	assert_eq(hud.equipment_label.text, "Fishing Rod")
	assert_not_null(hud.equipment_icon.texture)
	player.fishing_rod.toggle()
	hud.refresh()
	assert_true(hud.empty_icon.visible)


func test_quest_count_uses_existing_dda_target_without_completing_quest() -> void:
	QuestManager.start_quest("learn_post_harvest_basics")
	DDAController.current_tier = DDAController.DifficultyTier.EASY
	hud.refresh()
	assert_eq(hud.quest_title.text, "Learn the Basics")
	assert_string_contains(hud.quest_objective.text, "(0/1)")
	DDAController.current_tier = DDAController.DifficultyTier.HARD
	hud.refresh()
	assert_string_contains(hud.quest_objective.text, "(0/2)")
	QuestManager.update_quest_progress("learn_post_harvest_basics", {"objectives_complete": true})
	hud.refresh()
	assert_string_contains(hud.quest_objective.text, "Return to the quest giver")
	assert_eq(QuestManager.get_quest_state("learn_post_harvest_basics"), "active")


func test_shortcuts_open_existing_screens_and_release_their_pauses() -> void:
	hud.shortcuts.Codex.pressed.emit()
	assert_true(codex.visible)
	assert_true(get_tree().paused)
	codex.close_codex()
	hud.shortcuts.Inventory.pressed.emit()
	assert_true(inventory.visible)
	inventory.close_inventory()
	hud.shortcuts.Quests.pressed.emit()
	assert_true(journal.visible)
	assert_true(get_tree().paused)
	journal.close_journal()
	assert_false(get_tree().paused)
	hud.shortcuts.Performance.pressed.emit()
	assert_true(board.visible)
	var close_key := InputEventKey.new()
	close_key.keycode = KEY_P
	close_key.pressed = true
	hud._input(close_key)
	assert_false(board.visible)
	assert_false(get_tree().paused)
	hud.explore_button.pressed.emit()
	assert_true(world.visible)
	world.close_map()
	assert_false(get_tree().paused)


func test_hud_hides_for_foreign_pause_and_never_releases_it() -> void:
	GameManager.set_paused(true)
	hud.refresh()
	assert_false(hud.visible)
	assert_false(hud.toggle_quests())
	assert_true(get_tree().paused)


func test_responsive_layout_keeps_required_controls_on_screen_without_overlap() -> void:
	hud.touch_controls_mode = 1
	for viewport in [
		Vector2(856, 428),
		Vector2(598, 896),
		Vector2(1152, 648),
		Vector2(1280, 720),
		Vector2(1600, 720),
		Vector2(1920, 1080),
		Vector2(1200, 760),
		Vector2(390, 844),
		Vector2(720, 360)
	]:
		ui_root.size = viewport
		for i in range(4):
			await get_tree().process_frame
		hud.refresh()
		mini.refresh()
		var screen := Rect2(Vector2.ZERO, viewport)
		var controls := [
			hud.equipment,
			hud.quest_panel,
			hud.region_panel,
			hud.menu_button,
			hud.joystick,
			hud.interact_button,
			hud.explore_button,
			mini
		]
		for control in controls:
			assert_true(
				screen.grow(1).encloses(control.get_global_rect()),
				str(viewport) + ": " + str(control.name)
			)
		for i in range(controls.size()):
			for j in range(i + 1, controls.size()):
				assert_false(
					controls[i].get_global_rect().intersects(controls[j].get_global_rect()),
					str(viewport) + ": " + str(controls[i].name) + " / " + str(controls[j].name)
				)


func _touch(index: int, pos: Vector2, down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = down
	return event


func test_multitouch_joystick_and_interaction_share_existing_player_signals() -> void:
	hud.touch_controls_mode = 1
	hud.refresh()
	var center: Vector2 = hud.joystick.get_global_transform_with_canvas() * (hud.joystick.size / 2)
	hud.joystick._input(
		_touch(
			0,
			(
				hud.joystick.get_global_transform_with_canvas()
				* (hud.joystick.size / 2 + Vector2(50, 0))
			),
			true
		)
	)
	assert_gt(hud.joystick.direction.x, 0.8)
	player.input._process(0)
	assert_gt(player.movement._move_input.x, 0.8)
	var target := Interactable.new()
	target.position = player.global_position
	add_child_autofree(target)
	player.interaction._in_range.append(target)
	hud.refresh()
	watch_signals(target)
	var action: Vector2 = (
		hud.interact_button.get_global_transform_with_canvas() * (hud.interact_button.size / 2)
	)
	hud.interact_button._input(_touch(1, action, true))
	hud.interact_button._input(_touch(1, action, false))
	assert_signal_emit_count(target, "interacted", 1)
	assert_gt(hud.joystick.direction.x, 0.8, "Second finger does not release the joystick")
	hud.joystick._input(_touch(0, center, false))
	player.input._process(0)
	assert_eq(player.movement._move_input, Vector2.ZERO)


func test_touch_dead_zone_cancel_and_hidden_controls_clear_input() -> void:
	hud.touch_controls_mode = 1
	hud.refresh()
	var center: Vector2 = hud.joystick.get_global_transform_with_canvas() * (hud.joystick.size / 2)
	hud.joystick._input(
		_touch(
			0,
			(
				hud.joystick.get_global_transform_with_canvas()
				* (hud.joystick.size / 2 + Vector2(2, 0))
			),
			true
		)
	)
	assert_eq(hud.joystick.direction, Vector2.ZERO)
	hud.joystick.reset()
	hud.joystick._input(
		_touch(
			0,
			(
				hud.joystick.get_global_transform_with_canvas()
				* (hud.joystick.size / 2 + Vector2(50, 0))
			),
			true
		)
	)
	hud.toggle_menu()
	hud._process(0)
	assert_true(get_tree().paused)
	assert_true(hud.menu_panel.visible)
	assert_false(hud.exploration.visible)
	assert_eq(player.input._touch_direction, Vector2.ZERO)
	hud.close_menu()
	assert_false(get_tree().paused)
	hud._process(0)
	assert_true(hud.exploration.visible)


func test_keyboard_still_drives_movement_and_dialogue_blocks_gameplay_input() -> void:
	Input.action_press("move_right")
	player.input._process(0)
	assert_gt(player.movement._move_input.x, 0.9)
	DialogueManager.is_active = true
	player.input._process(0)
	assert_eq(player.movement._move_input, Vector2.ZERO)
	watch_signals(player.input)
	player.input.request_interact()
	assert_signal_not_emitted(player.input, "interact_pressed")
	DialogueManager.is_active = false
	Input.action_release("move_right")
	player.input._process(0)


func test_menu_handoff_collapse_and_foreign_pause() -> void:
	hud.toggle_menu()
	hud.shortcuts.Inventory.pressed.emit()
	assert_true(inventory.visible)
	assert_false(hud.menu_panel.visible)
	assert_true(get_tree().paused)
	inventory.close_inventory()
	assert_false(get_tree().paused)
	hud._toggle_tracker()
	assert_false(hud.quest_details.visible)
	hud._toggle_tracker()
	assert_true(hud.quest_details.visible)
	GameManager.set_paused(true)
	hud.toggle_menu()
	assert_false(hud.menu_panel.visible)
	hud.close_menu()
	assert_true(get_tree().paused)


func test_fishing_and_question_modes_hide_controls_but_keep_existing_answers_touchable() -> void:
	var old_state: int = FishingManager._state
	var fishing = _screen("res://Scene/UI/fishing_ui.tscn", "FishingUI", false)
	FishingManager._state = FishingManager.FlowState.CASTING
	hud._process(0)
	assert_false(hud.exploration.visible)
	FishingManager._state = FishingManager.FlowState.AWAITING_MAIN_ANSWER
	GameManager.set_paused(true)
	fishing._display_question(
		{
			"id": "hud_layout_only",
			"text": "Layout verification",
			"choices": ["Option one", "Option two"]
		},
		false
	)
	await get_tree().process_frame
	assert_true(fishing.visible)
	for button in fishing.choices_container.get_children():
		assert_gte(button.size.y, 48.0)
		assert_true(button.can_process())
	fishing.hide()
	FishingManager._state = old_state
	GameManager.set_paused(false)
	hud._process(0)
	assert_true(hud.exploration.visible)


func test_dialogue_continue_is_touchable_and_hud_restores_after_close() -> void:
	var dialogue = _screen("res://Scene/UI/dialogue_ui.tscn", "DialogueUi", false)
	DialogueManager.start_dialogue(
		"hud_validation", [{"speaker": "Guide", "text": "Layout verification."}]
	)
	await get_tree().process_frame
	hud._process(0)
	assert_true(dialogue.visible)
	assert_false(hud.exploration.visible)
	assert_gte(dialogue.continue_button.size.y, 48.0)
	dialogue.continue_button.pressed.emit()
	await get_tree().process_frame
	hud._process(0)
	assert_false(DialogueManager.is_active)
	assert_true(hud.exploration.visible)


func test_input_adapter_is_safe_after_player_leaves_the_tree() -> void:
	var input := PlayerInputComponent.new()
	add_child(input)
	remove_child(input)
	input.set_touch_direction(Vector2.RIGHT)
	assert_false(input.can_accept_gameplay_input())
	assert_eq(input._touch_direction, Vector2.ZERO)
	input.free()


func test_dense_display_scale_preserves_touch_targets_and_layout() -> void:
	ui_root.size = Vector2(1920, 1080)
	hud.touch_controls_mode = 1
	hud.hud_scale = 3.0
	for i in range(4):
		await get_tree().process_frame
	hud.refresh()
	var screen := Rect2(Vector2.ZERO, ui_root.size)
	for control in [
		hud.equipment,
		hud.quest_panel,
		hud.region_panel,
		hud.menu_button,
		hud.joystick,
		hud.interact_button,
		mini,
		hud.explore_button
	]:
		assert_true(screen.encloses(control.get_global_rect()), str(control.name))
	assert_gte(hud.explore_button.get_global_rect().size.y, 144.0)
	assert_false(hud.joystick.get_global_rect().intersects(hud.quest_panel.get_global_rect()))
	assert_false(
		hud.interact_button.get_global_rect().intersects(hud.quest_panel.get_global_rect())
	)


func test_reference_interaction_is_contextual_and_explore_opens_existing_map() -> void:
	hud.refresh()
	assert_false(hud.interact_button.visible)
	var npc := NPC.new()
	npc.npc_id = "teacher_ana"
	add_child_autofree(npc)
	player.interaction._in_range.append(npc)
	hud.refresh()
	assert_true(hud.interact_button.visible)
	assert_eq(hud.interact_button.text, "Talk")
	player.interaction._in_range.clear()
	hud.refresh()
	assert_false(hud.interact_button.visible)
	hud.explore_button.pressed.emit()
	assert_true(world.visible)
	world.close_map()


func test_prompt_width_follows_context_and_keeps_touch_height() -> void:
	var widths: Dictionary = {}
	for text in ["Talk", "Fish", "Collect", "Inspect", "Interact"]:
		hud.interact_button.text = text
		hud._layout()
		widths[text] = hud.interact_button.size.x
		assert_gte(hud.interact_button.size.y, 48.0)
		assert_gte(hud.interact_button.size.x, hud.interact_button.get_combined_minimum_size().x)
	assert_lt(widths.Talk, 180.0)
	assert_gt(widths.Inspect, widths.Talk)
	var target := Interactable.new()
	target.prompt_text = "Inspect the landing supplies"
	add_child_autofree(target)
	player.interaction._in_range.append(target)
	hud.refresh()
	assert_eq(hud.interact_button.text, "Inspect")


func test_long_quest_text_remains_bounded_with_full_journal_access() -> void:
	hud.set_process(false)
	for viewport in [
		Vector2(856, 428),
		Vector2(1280, 720),
		Vector2(1920, 1080),
		Vector2(598, 896),
		Vector2(720, 360)
	]:
		ui_root.size = viewport
		hud.quest_title.text = "A very long active quest title that must remain readable inside a compact gameplay tracker"
		hud.quest_objective.text = "Inspect a particularly long objective description without overflowing the current quest card\nVisit the second objective without losing its details"
		for i in range(5):
			hud._layout()
			await get_tree().process_frame
		var screen := Rect2(Vector2.ZERO, viewport)
		assert_true(screen.encloses(hud.quest_panel.get_global_rect()), str(viewport))
		assert_true(
			hud.quest_panel.get_global_rect().encloses(hud.quest_title.get_global_rect()),
			"Title stays inside the card"
		)
		assert_false(
			hud.quest_panel.get_global_rect().intersects(hud.explore_button.get_global_rect()),
			"Long title does not push into Explore"
		)
		assert_lte(hud.quest_title.max_lines_visible, 2)
		assert_gt(hud.quest_title.get_visible_line_count(), 0, "Quest title must actually render")
		if hud.quest_details.visible:
			assert_gt(
				hud.quest_objective.get_visible_line_count(), 0, "Objective must actually render"
			)
	assert_eq(
		hud.quest_objective.max_lines_visible,
		-1,
		"All objective lines remain available by scrolling"
	)
	assert_gt(hud.quest_details.get_v_scroll_bar().max_value, hud.quest_details.size.y)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	hud.quest_title.gui_input.emit(event)
	assert_true(journal.visible, "Complete journal is still available")
	journal.close_journal()


func test_regular_quest_title_and_objective_have_a_full_visible_line() -> void:
	QuestManager.start_quest("learn_post_harvest_basics")
	hud.refresh()
	for i in range(4):
		await get_tree().process_frame
	assert_gt(hud.quest_title.get_visible_line_count(), 0)
	assert_gt(hud.quest_objective.get_visible_line_count(), 0)
	assert_gte(hud.quest_details.size.y, float(hud.quest_objective.get_line_height()))


func test_hud_controls_and_styles_exist_in_the_saved_scene() -> void:
	var editable := HUD.instantiate()
	for name in [
		"EquipmentStatus",
		"EquipmentName",
		"Points",
		"CurrentQuest",
		"QuestTitle",
		"QuestObjective",
		"RegionBadge",
		"MenuButton",
		"ExploreButton",
		"MiniMapSlot",
		"CodexButton",
		"InventoryButton",
		"QuestsButton"
	]:
		var control: Node = editable.get_node("%" + name)
		assert_eq(control.owner, editable, name + " is editable in the local scene")
	assert_not_null(editable.get_node("%EquipmentStatus").get_theme_stylebox("panel"))
	for name in ["CodexButton", "InventoryButton", "QuestsButton"]:
		assert_null(editable.get_node("%" + name).icon)
	editable.free()


func test_scene_spacing_and_styles_survive_refresh() -> void:
	hud.actions.add_theme_constant_override("separation", 14)
	var panel: StyleBoxTexture = hud.equipment.get_theme_stylebox("panel").duplicate()
	panel.content_margin_left = 18
	hud.equipment.add_theme_stylebox_override("panel", panel)
	for i in range(3):
		hud.refresh()
	assert_eq(hud.actions.get_theme_constant("separation"), 14)
	assert_eq(hud.equipment.get_theme_stylebox("panel").content_margin_left, 18.0)


func test_responsive_scene_adjustments_do_not_accumulate() -> void:
	hud.refresh()
	var original_position: Vector2 = hud.menu_button.position
	var original_size: Vector2 = hud.menu_button.size
	hud._authored_layout[hud.menu_button] = Rect2(Vector2(10, 6), Vector2(20, 0))
	for i in range(4):
		hud.refresh()
	assert_eq(hud.menu_button.position, original_position + Vector2(10, 6))
	assert_eq(hud.menu_button.size, original_size + Vector2(20, 0))


func test_manual_layout_preserves_control_rectangles_and_minimap_slot() -> void:
	hud.responsive_layout = false
	hud.menu_button.position = Vector2(36, 140)
	hud.menu_button.size = Vector2(140, 56)
	hud._mini_map_slot.position = Vector2(900, 32)
	hud._mini_map_slot.size = Vector2(128, 128)
	for i in range(3):
		hud.refresh()
	assert_eq(hud.menu_button.get_rect(), Rect2(36, 140, 140, 56))
	assert_eq(mini.global_position, hud._mini_map_slot.global_position)
	assert_eq(mini.size, hud._mini_map_slot.size)


func test_minimap_player_arrow_follows_movement_and_retains_idle_facing() -> void:
	for direction in [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, -1).normalized()
	]:
		player.movement.set_move_input(direction)
		mini.refresh()
		assert_eq(mini.surface.player_facing, direction)
		mini.surface._process(0.8)
		var tip: Vector2 = mini.surface.player_indicator_points()[0] - mini.surface.size * 0.5
		assert_almost_eq(tip.normalized().x, direction.x, 0.001)
		assert_almost_eq(tip.normalized().y, direction.y, 0.001)
		player.movement.set_move_input(Vector2.ZERO)
		mini.refresh()
		assert_eq(mini.surface.player_facing, direction, "Idle retains the last facing")


func test_minimap_camera_and_marker_follow_the_same_player_position() -> void:
	for position in [Vector2(100, 50), Vector2(-45, 80), Vector2(60, -30)]:
		player.global_position = position
		mini.refresh()
		assert_eq(mini.map_camera.position, position)
		assert_eq(mini.surface.player_position, position)


func test_minimap_arrow_is_slightly_larger_and_turns_gradually() -> void:
	var marker := preload("res://Scripts/UI/MiniMapSurface.gd").new()
	add_child_autofree(marker)
	marker.size = Vector2(120, 120)
	marker.player_facing = Vector2.UP
	marker.player_facing = Vector2.RIGHT
	var center: Vector2 = marker.size / 2
	var before: Vector2 = marker.player_indicator_points()[0] - center
	assert_almost_eq(before.length(), 7.5, 0.001, "25 percent larger")
	marker._process(1.0 / 60)
	var intermediate: Vector2 = marker.player_indicator_points()[0] - center
	assert_gt(intermediate.x, 0.0)
	assert_lt(intermediate.y, 0.0, "Turns through intermediate angles instead of snapping")
	marker._process(0.8)
	var final_tip: Vector2 = marker.player_indicator_points()[0] - center
	assert_almost_eq(final_tip.normalized().x, 1.0, 0.001)
	assert_almost_eq(final_tip.normalized().y, 0.0, 0.001)


func test_minimap_arrow_smoothing_is_frame_rate_independent_and_uses_short_turn() -> void:
	var markers: Array[Control] = []
	for fps in [30, 60, 120]:
		var marker := preload("res://Scripts/UI/MiniMapSurface.gd").new()
		add_child_autofree(marker)
		marker.player_facing = Vector2.from_angle(PI - 0.1)
		marker.player_facing = Vector2.from_angle(-PI + 0.1)
		for i in fps / 10:
			marker._process(1.0 / fps)
		markers.append(marker)
		var tip: Vector2 = marker.player_indicator_points()[0] - marker.size / 2
		assert_lt(tip.x, 0.0, "Crosses the angle seam without a full rotation")
	for marker in markers:
		assert_almost_eq(marker._display_angle, markers[0]._display_angle, 0.001)


func test_quest_sidebar_collapses_to_a_reopen_tab_without_losing_content() -> void:
	QuestManager.start_quest("learn_post_harvest_basics")
	hud.refresh()
	var title: String = hud.quest_title.text
	var objective: String = hud.quest_objective.text
	hud.collapse_button.pressed.emit()
	hud.refresh()
	assert_false(hud.quest_panel.visible)
	assert_true(hud.collapse_button.is_visible_in_tree())
	assert_eq(hud.collapse_button.text, "")
	assert_string_contains(hud.collapse_button.icon.resource_path, "sidebar-expand")
	assert_false(get_tree().paused)
	hud.collapse_button.pressed.emit()
	hud.refresh()
	assert_true(hud.quest_panel.visible)
	assert_eq(hud.quest_title.text, title)
	assert_eq(hud.quest_objective.text, objective)
	assert_string_contains(hud.collapse_button.icon.resource_path, "sidebar-collapse")


func test_quest_sidebar_tab_remains_reachable_at_supported_sizes() -> void:
	for resolution in [
		Vector2(856, 428),
		Vector2(1280, 720),
		Vector2(1920, 1080),
		Vector2(598, 896),
		Vector2(720, 360)
	]:
		ui_root.size = resolution
		for i in 3:
			await get_tree().process_frame
		for collapsed in [true, false]:
			if hud._quest_collapsed != collapsed:
				hud.collapse_button.pressed.emit()
			hud.refresh()
			assert_true(
				Rect2(Vector2.ZERO, resolution).encloses(hud.collapse_button.get_global_rect())
			)
			assert_gte(hud.collapse_button.size.x, 48.0)
			assert_gte(hud.collapse_button.size.y, 48.0)


func test_field_guide_fits_normal_screens_and_keeps_close_fixed_on_short_screens() -> void:
	for dimensions in [Vector2(1200,760), Vector2(390,844), Vector2(720,360)]:
		ui_root.size = dimensions
		hud._layout()
		hud.toggle_menu()
		for frame in 12:
			await get_tree().process_frame
		var scroll: ScrollContainer = hud.get_node("%MenuScroll")
		var close: Button = hud.get_node("%CloseMenuButton")
		assert_eq(hud.actions.get_child_count(),4)
		assert_false(scroll.is_ancestor_of(close))
		assert_gte(close.size.y,48.0)
		if dimensions.y > 500:
			assert_false(scroll.get_v_scroll_bar().visible)
			for button in hud.actions.get_children():
				assert_true(scroll.get_global_rect().encloses(button.get_global_rect()))
		else:
			assert_true(scroll.get_v_scroll_bar().visible)
		close.pressed.emit()
		assert_false(get_tree().paused)
