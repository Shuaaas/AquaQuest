@tool
extends Control
## One captured finger; other touch indices remain available to HUD controls.
const STYLE := preload("res://Scripts/UI/HUDReferenceStyle.gd")
signal direction_changed(direction: Vector2)
@export_range(0.0, 0.9) var dead_zone := 0.18
@export_range(0.2, 3.0) var sensitivity := 1.0
var direction := Vector2.ZERO
var _finger := -1
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(
		func():
			if not is_visible_in_tree():
				reset()
	)
	resized.connect(queue_redraw)


func reset() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	if direction != Vector2.ZERO:
		direction = Vector2.ZERO
		direction_changed.emit(direction)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and _finger == -1 and local.distance_to(size / 2) <= size.x / 2:
			_finger = event.index
			_update_direction(local)
		elif event.index == _finger and not event.pressed:
			reset()
		else:
			return
	elif event is InputEventScreenDrag and event.index == _finger:
		_update_direction(get_global_transform_with_canvas().affine_inverse() * event.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _update_direction(local: Vector2) -> void:
	var radius := size.x * 0.32
	_knob = (local - size / 2).limit_length(radius)
	var strength := clampf(_knob.length() / radius, 0, 1)
	var next := Vector2.ZERO
	if strength > dead_zone:
		next = (
			_knob.normalized()
			* clampf((strength - dead_zone) / (1 - dead_zone) * sensitivity, 0, 1)
		)
	if next != direction:
		direction = next
		direction_changed.emit(direction)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()


func _draw() -> void:
	var center := size / 2
	var radius := size.x * 0.46
	draw_circle(center + Vector2(0, 2), radius, STYLE.SHADOW)
	var olive := STYLE.GREEN.darkened(0.55)
	olive.a = 0.68
	draw_circle(center, radius, olive)
	draw_arc(center, radius - 1, 0, TAU, 96, STYLE.GOLD, 2, true)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var point: Vector2 = center + axis * (radius - 11)
		var side: Vector2 = axis.orthogonal() * 4
		draw_colored_polygon(
			PackedVector2Array(
				[point + axis * 4, point - axis * 3 + side, point - axis * 3 - side]
			),
			STYLE.PARCHMENT
		)
	draw_circle(center + _knob, radius * 0.36, STYLE.GOLD.darkened(0.2))
	draw_arc(center + _knob, radius * 0.36, 0, TAU, 64, STYLE.GOLD, 2, true)
