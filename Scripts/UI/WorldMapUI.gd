extends Control
## Persistent, read-only atlas. There is no fast-travel feature in this project.

var _info_visible := true
var _user_toggled_info := false
var _selected_region: String = "region_1"
var _owns_pause := false
var _previous_focus: WeakRef
var _buttons: Dictionary = {}

@onready var canvas: Control = %MapCanvas
@onready var information: RichTextLabel = %Information
@onready var close_button: Button = %CloseButton
@onready var columns: BoxContainer = %MapColumns
@onready var info_scroll: ScrollContainer = %InfoScroll
@onready var region_buttons: Control = %RegionButtons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Copy source data only; duplicating a live font also copies its glyph cache.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	%DetailsButton.pressed.connect(_toggle_details)
	%RegionSelector.item_selected.connect(_on_region_selected)
	canvas.resized.connect(_position_region_buttons)
	%AtlasStage.resized.connect(_update_layout)
	%RegionCard.minimum_size_changed.connect(_update_layout)
	close_button.pressed.connect(close_map)
	canvas.region_selected.connect(select_region)
	EventBus.world_map_open_requested.connect(open_map)
	EventBus.map_data_changed.connect(_refresh)
	resized.connect(_update_layout)
	for entry in MapManager.get_regions():
		var button := Button.new()
		var region_id: String = entry["region_id"]
		button.text = region_id.replace("_", " ").capitalize()
		button.tooltip_text = region_id.replace("_", " ").capitalize()
		button.custom_minimum_size = Vector2(48, 48)
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_FILL
		button.toggle_mode = true
		button.pressed.connect(select_region.bind(region_id))
		region_buttons.add_child(button)
		_buttons[region_id] = button
		%RegionSelector.add_item(region_id.replace("_", " ").capitalize())
		%RegionSelector.set_item_metadata(%RegionSelector.item_count - 1, region_id)
	_update_layout()


func open_map() -> bool:
	if visible:
		return true
	if not can_open():
		UIManager.show_notification(
			"Finish or close the current interaction before opening the map."
		)
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	GameManager.set_paused(true)
	_owns_pause = true
	show()
	if RegionManager.current_region_id != "":
		_selected_region = RegionManager.current_region_id
	select_region(_selected_region, false)
	close_button.grab_focus()
	return true


func can_open() -> bool:
	return (
		not get_tree().paused
		and not SaveManager.is_loading
		and not SceneLoader.is_loading()
		and not DialogueManager.is_active
		and not FishingManager.is_fishing()
		and not MapManager.has_blocking_overlay(self)
		and GameManager.current_state in [GameManager.GameState.BOOT, GameManager.GameState.PLAYING]
	)


func close_map() -> void:
	hide()
	_release_pause()
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		GameManager.set_paused(false)


func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var toggle: bool = event is InputEventKey and event.pressed and not event.echo
	if toggle:
		toggle = event.keycode == KEY_M and not event.ctrl_pressed
	if event.is_action_pressed("ui_cancel") or toggle:
		close_map()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func select_region(region_id: String, reveal_details: bool = true) -> void:
	var info := MapManager.get_region_info(region_id)
	if info.is_empty():
		return
	_selected_region = region_id
	canvas.selected_region_id = region_id
	canvas.refresh_state()
	if reveal_details:
		_info_visible = true
		_user_toggled_info = true
	for button_id: String in _buttons:
		_buttons[button_id].set_pressed_no_signal(button_id == region_id)
	%RegionName.text = info["name"]
	%RegionModule.text = (
		"%s · %s"
		% [
			region_id.replace("_", " ").capitalize(),
			info["module_id"].replace("_", " ").capitalize()
		]
	)
	%RegionPreview.texture = canvas.get_region_texture(region_id)
	for index in %RegionSelector.item_count:
		if %RegionSelector.get_item_metadata(index) == region_id:
			%RegionSelector.select(index)
	var status := "Locked"
	if info["unlocked"]:
		status = "Unlocked"
	if info["completed"]:
		status += " / Completed"
	if info["current"]:
		status += " / Current region"
	if not info["defined"]:
		status += " / Not yet available"
	%RegionStatus.text = status
	information.text = (
		"%s: %s\n\n%s\n\nStatus: %s\n\n"
		% [
			info["module_id"].replace("_", " ").capitalize(),
			info["module_title"],
			info["description"],
			status
		]
	)
	information.text += (
		"Main quests: %d / %d completed\nAvailable quests: %d\n\n"
		% [
			info["main_completed"],
			info["main_total"],
			info["available"],
		]
	)
	if info["exam_count"] > 0:
		information.text += (
			"Regional exam: %s\n\n" % ("Passed" if info["exams_passed"] else "Not passed")
		)
	information.text += "Use the region exits to travel. Selecting a region does not move your player."
	info_scroll.scroll_vertical = 0
	_update_layout()


func _refresh() -> void:
	if visible:
		select_region(_selected_region, false)


func _on_region_selected(index: int) -> void:
	select_region(str(%RegionSelector.get_item_metadata(index)))


func _toggle_details() -> void:
	_info_visible = not %RegionCard.visible
	_user_toggled_info = true
	_update_layout()


func _update_layout() -> void:
	if not is_node_ready():
		return
	var portrait := size.x < 840 and size.x < size.y * 1.25
	var short_screen := size.y < 500
	columns.vertical = portrait
	get_node("Margin/Panel/Book/Header/Titles/Subtitle").visible = not portrait
	get_node("Margin/Panel/Book/Header/Titles/Title").add_theme_font_size_override(
		"font_size", 18 if portrait else 22
	)
	%RegionSelector.visible = portrait or short_screen
	%RegionCard.visible = _info_visible and (not short_screen or _user_toggled_info)
	%DetailsButton.tooltip_text = (
		"Hide region details" if %RegionCard.visible else "Show region details"
	)
	var stage: Control = %AtlasStage
	%RegionCard.position = Vector2(8, maxf(0, stage.size.y - (220 if portrait else 200) - 8))
	%RegionCard.size = Vector2(
		minf(440, maxf(0, stage.size.x - 16)), minf(220 if portrait else 200, stage.size.y)
	)
	canvas.bottom_inset = (220.0 if portrait else 100.0) if %RegionCard.visible else 0.0
	canvas._layout_art()
	_position_region_buttons()


func _position_region_buttons() -> void:
	if not is_node_ready():
		return
	var compact := size.x < 900 or size.y < 500
	for entry in MapManager.get_regions():
		var id: String = entry["region_id"]
		var info := MapManager.get_region_info(id)
		var button: Button = _buttons[id]
		button.text = (
			id.replace("_", " ").capitalize()
			if compact
			else (
				"%s\n%s · %s"
				% [
					info["name"],
					id.replace("_", " ").capitalize(),
					entry["module_id"].replace("_", " ").capitalize()
				]
			)
		)
		button.tooltip_text = (
			"%s · %s%s"
			% [
				info["name"],
				entry["module_id"].replace("_", " ").capitalize(),
				(
					" · Not yet available"
					if not info["defined"]
					else (" · Locked" if not info["unlocked"] else "")
				)
			]
		)
		button.accessibility_name = button.tooltip_text
		button.size = Vector2(80 if compact else 172, 48 if compact else 56)
		var center: Vector2 = canvas.get_region_screen_position(id)
		button.position = center + Vector2(-button.size.x / 2, 56 * canvas._scale_factor())
		button.position.x = clampf(button.position.x, 0, maxf(0, canvas.size.x - button.size.x))
		button.position.y = clampf(button.position.y, 0, maxf(0, canvas.size.y - button.size.y))

		if %RegionCard.visible and %RegionCard.get_rect().intersects(button.get_rect()):
			button.position.y = maxf(0, %RegionCard.position.y - button.size.y - 8)
