extends Control
## Map-space overlay and pointer input; never moves the real player.
signal pan_requested(delta: Vector2)
signal zoom_requested(factor: float, point: Vector2)
signal marker_selected(marker: Dictionary)
const COLORS := preload("res://Scripts/UI/MiniMapSurface.gd").COLORS
var center := Vector2.ZERO
var pixels_per_world := 1.0
var markers: Array = []
var player_position := Vector2.ZERO
var player_facing := Vector2.DOWN
var _dragging := false
var _touch := -1
var _distance := 0.0


func project(world: Vector2) -> Vector2:
	return size / 2 + (world - center) * pixels_per_world


func _gui_input(event: InputEvent) -> void:
	# Ignore companion events synthesized from the same physical mouse/touch input.
	if event.device == -1:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_requested.emit(
				1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, event.position
			)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_distance = 0
			else:
				if _dragging and _distance < 8:
					_pick(event.position)
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_distance += event.relative.length()
		pan_requested.emit(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			_touch = event.index
			_distance = 0
		elif not event.pressed and event.index == _touch:
			if _distance < 8:
				_pick(event.position)
			_touch = -1
	elif event is InputEventScreenDrag and event.index == _touch:
		_distance += event.relative.length()
		pan_requested.emit(event.relative)
	elif event is InputEventMagnifyGesture:
		zoom_requested.emit(event.factor, event.position)
	accept_event()


func reset_input() -> void:
	_dragging = false
	_touch = -1


func _pick(point: Vector2) -> void:
	var closest := 22.0
	var selected: Dictionary = {}
	for marker in markers:
		var distance := project(marker.position).distance_to(point)
		if distance < closest:
			closest = distance
			selected = marker
	if not selected.is_empty():
		marker_selected.emit(selected)


func _draw() -> void:
	for marker in markers:
		var point := project(marker.position)
		if not Rect2(Vector2.ZERO, size).grow(12).has_point(point):
			continue
		var color: Color = COLORS.get(marker.kind, Color("e6d2ac"))
		draw_circle(point, 9, Color("21160f"), true, -1, true)
		if marker.kind in ["main_quest", "mini_quest"]:
			draw_line(point + Vector2(-3, 7), point + Vector2(-3, -7), color, 2, true)
			draw_colored_polygon(
				PackedVector2Array(
					[point + Vector2(-2, -7), point + Vector2(7, -4), point + Vector2(-2, 0)]
				),
				color
			)
		elif marker.kind in ["fishing", "exam"]:
			draw_colored_polygon(
				PackedVector2Array(
					[
						point + Vector2(0, -6),
						point + Vector2(6, 0),
						point + Vector2(0, 6),
						point + Vector2(-6, 0)
					]
				),
				color
			)
		elif marker.kind in ["shop", "exit"]:
			draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), color)
		else:
			draw_circle(point, 5, color, true, -1, true)
	var you := project(player_position)
	if Rect2(Vector2.ZERO, size).has_point(you):
		var facing := player_facing.normalized()
		var side := facing.orthogonal()
		draw_circle(you, 11, Color("21160f"), true, -1, true)
		draw_colored_polygon(
			PackedVector2Array(
				[you + facing * 10, you - facing * 7 + side * 6, you - facing * 7 - side * 6]
			),
			Color("f0dec1")
		)
		var font := get_theme_font("font", "Label")
		draw_style_box(
			get_theme_stylebox("normal", "Button"), Rect2(you + Vector2(-23, -40), Vector2(46, 24))
		)
		draw_string(
			font, you + Vector2(-13, -22), "You", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f0dec1")
		)
