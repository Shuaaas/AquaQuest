extends Control
## Persistent, read-only atlas. There is no fast-travel feature in this project.

var _selected_region: String = "region_1"
var _owns_pause := false
var _previous_focus: WeakRef
var _buttons: Dictionary = {}

@onready var canvas: Control = %MapCanvas
@onready var information: RichTextLabel = %Information
@onready var close_button: Button = %CloseButton
@onready var columns: BoxContainer = %MapColumns
@onready var info_scroll: ScrollContainer = %InfoScroll
@onready var region_buttons: HBoxContainer = %RegionButtons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_button.pressed.connect(close_map)
	canvas.region_selected.connect(select_region)
	EventBus.world_map_open_requested.connect(open_map)
	EventBus.map_data_changed.connect(_refresh)
	resized.connect(_update_layout)
	for entry in MapManager.get_regions():
		var button := Button.new()
		var region_id: String = entry["region_id"]
		button.text = "R" + region_id.trim_prefix("region_")
		button.tooltip_text = region_id.replace("_", " ").capitalize()
		button.custom_minimum_size = Vector2(48, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(select_region.bind(region_id))
		region_buttons.add_child(button)
		_buttons[region_id] = button
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
	select_region(_selected_region)
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


func select_region(region_id: String) -> void:
	var info := MapManager.get_region_info(region_id)
	if info.is_empty():
		return
	_selected_region = region_id
	canvas.selected_region_id = region_id
	canvas.queue_redraw()
	for button_id: String in _buttons:
		_buttons[button_id].set_pressed_no_signal(button_id == region_id)
	var region_label := region_id.replace("_", " ").capitalize()
	var status := "Locked"
	if info["unlocked"]:
		status = "Unlocked"
	if info["completed"]:
		status += " / Completed"
	if info["current"]:
		status += " / Current region"
	if not info["defined"]:
		status += " / Not yet available"
	var name_text: String = info["name"]
	if name_text != region_label:
		region_label += " - " + name_text
	information.text = (
		"%s\n\n%s\n\n%s: %s\n\nStatus: %s\n\n"
		% [
			region_label,
			info["description"],
			info["module_id"].replace("_", " ").capitalize(),
			info["module_title"],
			status,
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


func _refresh() -> void:
	if visible:
		select_region(_selected_region)


func _update_layout() -> void:
	if not is_node_ready():
		return
	var portrait := size.x < 840 and size.x < size.y * 1.25
	columns.vertical = portrait
	info_scroll.custom_minimum_size = (
		Vector2(0, 190) if portrait else Vector2(minf(300, size.x * 0.36), 0)
	)
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size.y = 200 if portrait else 0
