extends Control
## Native HUD presentation and input adapter; existing managers keep game rules.
const STATUS := preload("res://Scripts/UI/HUDStatus.gd")
const STYLE := preload("res://Scripts/UI/HUDReferenceStyle.gd")
## Disable to use only scene anchors/offsets; mobile adaptation then becomes manual.
@export var responsive_layout := true
@export_enum("Auto", "Always", "Never") var touch_controls_mode := 0
@export_range(48, 100, 4) var joystick_radius := 80.0
@export_range(0.0, 0.9) var joystick_dead_zone := 0.18
@export_range(0.2, 3.0) var joystick_sensitivity := 1.0
@export_range(112, 192, 8) var minimap_diameter := 144.0
@export_range(8, 32, 4) var edge_padding := 24.0
@export_range(0.75, 3.0, 0.25) var hud_scale := 1.0
var equipment: PanelContainer
var equipment_label: Label
var points_label: Label
var equipment_icon: TextureRect
var empty_icon: Label
var quest_panel: PanelContainer
var quest_title: Label
var quest_objective: Label
var quest_details: ScrollContainer
var collapse_button: Button
var region_panel: PanelContainer
var region_label: Label
var actions: VBoxContainer
var shortcuts: Dictionary = {}
var menu_button: Button
var menu_panel: PanelContainer
var menu_shade: ColorRect
var exploration: Control
var joystick: Control
var interact_button: Control
var explore_button: Button
var quest_heading: Label
var quest_header: HBoxContainer
var _mini_map_slot: Control
var _authored_layout: Dictionary = {}
var _title_font_size := 18
var _heading_font_size := 16
var _mini_map: Control
var _inventory: Control
var _journal: Control
var _board: Control
var _player: Player
var _owns_board_pause := false
var _owns_menu_pause := false
var _quest_collapsed := false
var _elapsed := 0.0
var _equipment_id := "__uninitialized"
var _has_player := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mini_map = get_node_or_null("../MiniMapUI") as Control
	_inventory = get_node_or_null("../InventoryUI") as Control
	_journal = get_node_or_null("../QuestJournalUI") as Control
	_board = get_node_or_null("../PerformanceBoard") as Control
	if _board != null:
		_board.visibility_changed.connect(_on_board_visibility_changed)
	_bind_scene()
	resized.connect(_layout)
	refresh()


func _bind_scene() -> void:
	equipment = %EquipmentStatus
	equipment_label = %EquipmentName
	points_label = %Points
	equipment_icon = %EquipmentIcon
	empty_icon = %EmptyEquipment
	quest_panel = %CurrentQuest
	quest_title = %QuestTitle
	quest_objective = %QuestObjective
	quest_details = %QuestDetails
	collapse_button = %CollapseQuest
	region_panel = %RegionBadge
	region_label = %RegionName
	actions = %FieldGuideActions
	menu_button = %MenuButton
	menu_panel = %HUDMenu
	menu_shade = %MenuShade
	exploration = %Exploration
	joystick = %VirtualJoystick
	interact_button = %ContextInteraction
	explore_button = %ExploreButton
	quest_heading = %QuestHeading
	quest_header = %QuestHeader
	_mini_map_slot = %MiniMapSlot
	%EquipmentButton.pressed.connect(_open_inventory)
	collapse_button.pressed.connect(_toggle_tracker)
	menu_button.pressed.connect(toggle_menu)
	joystick.direction_changed.connect(_on_touch_direction)
	interact_button.pressed.connect(_interact)
	explore_button.pressed.connect(func(): EventBus.world_map_open_requested.emit())
	%CloseMenuButton.pressed.connect(close_menu)
	for label in ["Codex", "Inventory", "Quests", "Performance"]:
		var button: Button = get_node("%" + label + "Button")
		shortcuts[label] = button
		button.pressed.connect(_open_shortcut.bind(label))
	quest_title.gui_input.connect(_on_quest_click)
	quest_panel.gui_input.connect(_on_quest_click)
	menu_shade.gui_input.connect(
		func(event):
			if event is InputEventMouseButton and event.pressed:
				close_menu()
	)
	# Read saved offsets, before wrapped labels can inflate a container's initial size.
	var scene_state := (load(scene_file_path) as PackedScene).get_state()
	for control in _layout_controls():
		var authored := Rect2(control.position, control.size)
		for i in scene_state.get_node_count():
			if str(scene_state.get_node_path(i)).trim_prefix("./") != str(get_path_to(control)):
				continue
			var offsets := {
				"offset_left": 0.0, "offset_top": 0.0, "offset_right": 0.0, "offset_bottom": 0.0
			}
			for j in scene_state.get_node_property_count(i):
				var key := str(scene_state.get_node_property_name(i, j))
				if offsets.has(key):
					offsets[key] = scene_state.get_node_property_value(i, j)
			authored = Rect2(
				offsets.offset_left,
				offsets.offset_top,
				offsets.offset_right - offsets.offset_left,
				offsets.offset_bottom - offsets.offset_top
			)
			break
		_authored_layout[control] = Rect2(
			authored.position - Vector2(control.get_meta("responsive_origin", authored.position)),
			authored.size - Vector2(control.get_meta("responsive_size", authored.size))
		)
	_title_font_size = quest_title.get_theme_font_size("font_size")
	_heading_font_size = quest_heading.get_theme_font_size("font_size")
	if _mini_map != null:
		var border := StyleBoxFlat.new()
		border.bg_color = STYLE.INNER
		border.border_color = STYLE.WOOD
		border.set_border_width_all(7)
		border.set_corner_radius_all(128)
		border.anti_aliasing = false
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			border.set_content_margin(side, 9)
		_mini_map.get_node("Panel").add_theme_stylebox_override("panel", border)


func _on_quest_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_quests()
		quest_title.accept_event()


func _layout_controls() -> Array[Control]:
	return [
		equipment,
		quest_panel,
		region_panel,
		menu_button,
		joystick,
		interact_button,
		menu_panel,
		explore_button,
		_mini_map_slot
	]


func _sync_minimap() -> void:
	if _mini_map != null:
		_mini_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_mini_map.global_position = _mini_map_slot.global_position
		_mini_map.size = _mini_map_slot.size
		_mini_map.scale = _mini_map_slot.scale


func _toggle_tracker() -> void:
	_quest_collapsed = not _quest_collapsed
	quest_details.visible = not _quest_collapsed
	collapse_button.icon = load(
		STYLE.ICON_ROOT + ("sidebar-expand.svg" if _quest_collapsed else "sidebar-collapse.svg")
	)
	collapse_button.tooltip_text = (
		"Show quest sidebar" if _quest_collapsed else "Collapse quest sidebar"
	)
	collapse_button.accessibility_name = collapse_button.tooltip_text
	quest_panel.visible = not _quest_collapsed
	quest_panel.reset_size()
	_layout()


func _safe_rect(padding_scale: float = 1.0) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var origin := Vector2(DisplayServer.window_get_position())
		var transform := get_viewport().get_screen_transform().affine_inverse()
		var top_left := transform * (Vector2(safe.position) - origin)
		var bottom_right := transform * (Vector2(safe.end) - origin)
		bounds = bounds.intersection(Rect2(top_left, bottom_right - top_left))
	return bounds.grow(-edge_padding * padding_scale)


func _layout() -> void:
	if equipment == null or size.x <= 0 or size.y <= 0:
		return
	quest_panel.visible = not _quest_collapsed
	var touch := (
		touch_controls_mode == 1
		or (touch_controls_mode == 0 and DisplayServer.is_touchscreen_available())
	)
	joystick.visible = touch
	joystick.dead_zone = joystick_dead_zone
	joystick.sensitivity = joystick_sensitivity
	if not responsive_layout:
		_sync_minimap()
		return
	var display_scale := hud_scale * maxf(1.0, minf(size.x / 1280.0, size.y / 720.0))
	if OS.has_feature("android") or OS.has_feature("ios"):
		display_scale = maxf(display_scale, DisplayServer.screen_get_dpi() / 160.0)
	display_scale = clampf(display_scale, 0.75, minf(3.0, minf(size.x / 512, size.y / 320)))
	var actual_safe := _safe_rect(display_scale)
	var safe := Rect2(actual_safe.position / display_scale, actual_safe.size / display_scale)
	var compact := safe.size.y < 500
	var short_screen := safe.size.y < 340
	var diameter := minf(minimap_diameter, 88 if short_screen else (112 if compact else 144))
	var joy_size := maxf(144, joystick_radius * 2)
	joystick.position = Vector2(
		safe.position.x + (0 if safe.size.x < 720 else 40),
		safe.end.y - joy_size - (0 if compact else 56)
	)
	joystick.size = Vector2.ONE * joy_size
	equipment.position = safe.position
	equipment.size = Vector2(minf(216, safe.size.x - diameter - 16), 72)
	_mini_map_slot.position = Vector2(safe.end.x - diameter, safe.position.y)
	_mini_map_slot.size = Vector2.ONE * diameter
	var right_width := minf(216, safe.size.x * 0.45)
	quest_heading.add_theme_font_size_override(
		"font_size", _heading_font_size - 2 if right_width < 216 else _heading_font_size
	)
	var location_width := minf(right_width, maxf(168, diameter))
	region_panel.position = Vector2(safe.end.x - location_width, safe.position.y + diameter + 8)
	region_panel.size = Vector2(location_width, 36 if short_screen else 40)
	menu_button.position = safe.position + Vector2(0, 80)
	menu_button.size = Vector2(112, 48)
	var quest_y := region_panel.position.y + region_panel.size.y + 12
	quest_title.max_lines_visible = 1 if compact else 2
	quest_title.add_theme_font_size_override(
		"font_size", _title_font_size - 2 if compact else _title_font_size
	)
	quest_objective.max_lines_visible = -1
	# Ellipsis labels need an explicit line height or containers may shrink them to 1px.
	var title_rows := mini(maxi(quest_title.get_line_count(), 1), quest_title.max_lines_visible)
	quest_title.custom_minimum_size.y = title_rows * quest_title.get_line_height() + 2
	var objective_rows := maxi(quest_objective.get_line_count(), 1)
	quest_objective.custom_minimum_size.y = objective_rows * quest_objective.get_line_height() + 2
	var preview_rows := mini(objective_rows, 1 if compact else 2)
	quest_details.custom_minimum_size.y = preview_rows * quest_objective.get_line_height() + 2
	quest_panel.position = Vector2(safe.end.x - right_width, quest_y)
	quest_details.visible = not _quest_collapsed and not short_screen
	quest_panel.reset_size()
	quest_panel.size = Vector2(right_width, 100 if _quest_collapsed or short_screen else 116)
	explore_button.size = Vector2(144, 64)
	explore_button.position = safe.end - explore_button.size - Vector2(0, 0 if compact else 24)
	var prompt_width := interact_button.get_combined_minimum_size().x
	interact_button.size = Vector2(prompt_width, 48)
	interact_button.position = Vector2(
		safe.get_center().x - prompt_width / 2, safe.end.y - 48 - (0 if compact else 48)
	)
	if safe.size.x < 580:
		interact_button.position.y = safe.end.y - joy_size - (0 if compact else 56) - 60
	menu_panel.size = Vector2(minf(340, safe.size.x), minf(360, safe.size.y))
	menu_panel.position = safe.position + (safe.size - menu_panel.size) / 2
	# Apply the designer's scene edits relative to the original responsive template.
	for control in _layout_controls():
		var adjustment: Rect2 = _authored_layout.get(control, Rect2())
		control.position += adjustment.position
		control.size += adjustment.size
		control.scale = Vector2.ONE * display_scale
		control.position = (control.position * display_scale).round()
	collapse_button.size = Vector2(48, 48)
	collapse_button.scale = quest_panel.scale
	collapse_button.position = (
		quest_panel.position + Vector2((quest_panel.size.x - 36) * display_scale, 6 * display_scale)
	)
	_sync_minimap()


func _process(delta: float) -> void:
	var blocked := _blocked()
	exploration.visible = _has_player and not blocked
	visible = _has_player and (not blocked or _owns_menu_pause)
	if blocked:
		_clear_touch()
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0
		refresh()


func _blocked() -> bool:
	return (
		get_tree().paused
		or DialogueManager.is_active
		or FishingManager.is_fishing()
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or MapManager.has_blocking_overlay()
	)


func refresh() -> void:
	if equipment_label == null:
		return
	var state := STATUS.snapshot()
	_has_player = state.has_player
	var next_player := MapManager.get_local_player(MapManager.get_current_region_root())
	if next_player != _player:
		_clear_touch()
		_player = next_player
	exploration.visible = _has_player and not _blocked()
	visible = _has_player and (exploration.visible or _owns_menu_pause)
	equipment_label.text = (
		state.equipment_name if not state.equipment_id.is_empty() else "Equip a rod"
	)
	points_label.text = "Points: %d" % int(state.points)
	region_label.text = state.region
	quest_title.text = state.quest.title
	quest_title.tooltip_text = str(state.quest.title) + " — open full Quest Journal"
	quest_heading.text = "Active Quest" if not state.quest.id.is_empty() else "Quest Journal"
	quest_objective.text = "◆ " + str(state.quest.text).replace("\n", "\n◆ ")
	quest_objective.tooltip_text = state.quest.text
	var id: String = state.equipment_id
	if id != _equipment_id:
		_equipment_id = id
		var path := ItemDatabase.get_icon_path(id)
		equipment_icon.texture = (
			load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
		)
	equipment_icon.visible = equipment_icon.texture != null
	empty_icon.visible = equipment_icon.texture == null
	interact_button.disabled = true
	interact_button.visible = false
	interact_button.text = "Interact"
	if is_instance_valid(_player):
		var target := _player.interaction.get_focused_interactable()
		if target != null:
			interact_button.disabled = false
			interact_button.visible = true
			interact_button.text = (
				"Fish"
				if target is FishingSpot
				else ("Talk" if target is NPC else target.get_prompt_text())
			)
			if interact_button.text.length() > 12:
				var verb := target.get_prompt_text().get_slice(" ", 0).capitalize()
				interact_button.text = (
					verb
					if verb in ["Talk", "Fish", "Collect", "Inspect", "Interact"]
					else "Interact"
				)
	interact_button.queue_redraw()
	_layout()


func _on_touch_direction(direction: Vector2) -> void:
	if is_instance_valid(_player):
		_player.input.set_touch_direction(direction)


func _clear_touch() -> void:
	if is_instance_valid(joystick):
		joystick.reset()
	if is_instance_valid(_player):
		_player.input.set_touch_direction(Vector2.ZERO)


func _interact() -> void:
	if is_instance_valid(_player) and not _blocked():
		_player.input.request_interact()


func toggle_menu() -> void:
	if _owns_menu_pause:
		close_menu()
	elif not _blocked():
		_clear_touch()
		_owns_menu_pause = true
		menu_shade.show()
		%MenuScroll.scroll_vertical = 0
		menu_panel.show()
		GameManager.set_paused(true)
		shortcuts.Codex.grab_focus()


func close_menu() -> void:
	if not _owns_menu_pause:
		return
	_owns_menu_pause = false
	menu_panel.hide()
	menu_shade.hide()
	GameManager.set_paused(false)


func _open_shortcut(which: String) -> void:
	close_menu()
	match which:
		"Codex":
			EventBus.codex_open_requested.emit()
		"Inventory":
			_open_inventory()
		"Quests":
			toggle_quests()
		"Performance":
			toggle_performance()


func _open_inventory() -> void:
	if _inventory != null:
		_inventory.open_inventory()


func toggle_quests() -> bool:
	if _journal == null:
		return false
	if _journal.visible:
		_journal.close_journal()
		return true
	return _journal.open_journal(str(STATUS.current_quest().id))


func toggle_performance() -> bool:
	if _board == null:
		return false
	if _board.visible:
		_board.hide()
		return true
	if _blocked():
		return false
	_owns_board_pause = true
	GameManager.set_paused(true)
	_board.show()

	return true


func _on_board_visibility_changed() -> void:
	if not _board.visible:
		_release_board_pause()


func _release_board_pause() -> void:
	if _owns_board_pause:
		_owns_board_pause = false
		GameManager.set_paused(false)


func _input(event: InputEvent) -> void:
	if menu_panel.visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if _owns_board_pause and _board != null and _board.visible:
		if (
			event.is_action_pressed("ui_cancel")
			or (
				event is InputEventKey
				and event.pressed
				and not event.echo
				and event.keycode == KEY_P
			)
		):
			_board.hide()
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	close_menu()
	_clear_touch()
	_release_board_pause()
