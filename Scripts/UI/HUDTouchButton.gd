@tool
extends Control
## An independent touch index lets interaction work while the joystick is held.
const STYLE := preload("res://Scripts/UI/HUDReferenceStyle.gd")
signal pressed
var disabled := false
var text := "Interact":
	set(value):
		if text == value:
			return
		text = value
		update_minimum_size()
		queue_redraw()
var _normal_style: StyleBoxTexture
var _pressed_style: StyleBoxTexture
var _keycap: StyleBoxFlat
var _finger := -1
var _held := false


func _ready() -> void:
	_normal_style = STYLE.panel("button", 8)
	_pressed_style = STYLE.panel("button", 8)
	_pressed_style.modulate_color = Color(0.8, 0.8, 0.8)
	_keycap = StyleBoxFlat.new()
	_keycap.bg_color = STYLE.PARCHMENT
	_keycap.border_color = STYLE.WOOD
	_keycap.set_border_width_all(1)
	_keycap.set_corner_radius_all(6)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(
		func():
			if not is_visible_in_tree():
				_release()
	)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _release() -> void:
	_finger = -1
	_held = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree() or disabled:
		_release()
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, size).has_point(local)
		if event.pressed and inside and _finger == -1:
			_finger = event.index
			_held = true
		elif not event.pressed and event.index == _finger:
			_release()
			if inside and not event.canceled:
				pressed.emit()
		else:
			return
		queue_redraw()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
		var was_held := _held
		_held = event.pressed
		if not event.pressed and was_held and Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()
		queue_redraw()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()


func _get_minimum_size() -> Vector2:
	var label_width := (
		get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	)
	return Vector2(maxf(128, ceilf(label_width) + 88), 48)


func _draw() -> void:
	if _normal_style == null:
		return
	draw_style_box(_pressed_style if _held else _normal_style, Rect2(Vector2.ZERO, size))
	if has_focus():
		draw_rect(
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			STYLE.SELECTED.lightened(0.35),
			false,
			2,
			false
		)
	#draw_style_box(_keycap, Rect2(12, (size.y - 28) / 2, 28, 28))
	var font := get_theme_default_font()
	#draw_string(
		#font, Vector2(20, size.y / 2 + 7), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, STYLE.INK
	#)
	draw_string(
		font, Vector2(52, size.y / 2 + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, STYLE.CREAM
	)
	draw_texture_rect(STYLE.LEAVES, Rect2(size.x - 21, size.y - 22, 20, 20), false)
