extends Control
## Illustrated overview only; all region state comes from MapManager.
signal region_selected(region_id: String)
const ATLAS_SIZE := Vector2(960, 520)
const GOLD := Color("c6a66a")
var selected_region_id := ""
var bottom_inset := 0.0
var _islands: Dictionary = {}
var _textures: Dictionary = {}


func _ready() -> void:
	resized.connect(_layout_art)
	EventBus.map_data_changed.connect(refresh_state)
	for index in MapManager.get_regions().size():
		var entry: Dictionary = MapManager.get_regions()[index]
		var island: TextureRect = get_node("Island%d" % (index + 1))
		island.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		island.material = island.material.duplicate()
		_islands[entry["region_id"]] = island
		_textures[entry["region_id"]] = island.texture
	_layout_art()
	refresh_state()


func _scale_factor() -> float:
	return maxf(
		0.0,
		minf(
			size.x / ATLAS_SIZE.x,
			maxf(0, size.y - minf(bottom_inset, size.y * 0.55)) / ATLAS_SIZE.y
		)
	)


func _offset() -> Vector2:
	return (
		(
			Vector2(size.x, maxf(0, size.y - minf(bottom_inset, size.y * 0.55)))
			- ATLAS_SIZE * _scale_factor()
		)
		* 0.5
	)


func get_region_screen_position(region_id: String) -> Vector2:
	for entry in MapManager.get_regions():
		if entry["region_id"] == region_id:
			return (
				_offset()
				+ Vector2(entry["position"][0], entry["position"][1]) * ATLAS_SIZE * _scale_factor()
			)
	return Vector2.ZERO


func get_region_texture(region_id: String) -> Texture2D:
	return _textures.get(region_id)


func _layout_art() -> void:
	for region_id in _islands:
		var extent := Vector2.ONE * (220 if region_id == "region_5" else 260) * _scale_factor()
		_islands[region_id].size = extent
		_islands[region_id].position = get_region_screen_position(region_id) - extent / 2
	queue_redraw()


func refresh_state() -> void:
	for region_id in _islands:
		var info := MapManager.get_region_info(region_id)
		var state: ShaderMaterial = _islands[region_id].material
		state.set_shader_parameter("locked", not info["unlocked"])
		state.set_shader_parameter("unavailable", not info["defined"])
		state.set_shader_parameter("selected", selected_region_id == region_id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	pressed = pressed or event is InputEventScreenTouch
	if not pressed or not event.pressed:
		return
	var nearest := ""
	var distance := INF
	for entry in MapManager.get_regions():
		var next := get_region_screen_position(entry["region_id"]).distance_to(event.position)
		if next < distance:
			distance = next
			nearest = entry["region_id"]
	if not nearest.is_empty() and distance <= maxf(24, 90 * _scale_factor()):
		region_selected.emit(nearest)
		accept_event()


func _draw() -> void:
	var entries := MapManager.get_regions()
	for index in range(entries.size() - 1):
		var from := get_region_screen_position(entries[index]["region_id"])
		var to := get_region_screen_position(entries[index + 1]["region_id"])
		for step in range(6, 19):
			draw_circle(from.lerp(to, float(step) / 25), 2, Color("c8b18c"))
	for entry in entries:
		var center := get_region_screen_position(entry["region_id"])
		var info := MapManager.get_region_info(entry["region_id"])
		if info["current"]:
			var tip := center + Vector2(0, -30)
			draw_colored_polygon(
				PackedVector2Array([tip, tip + Vector2(-7, -15), tip + Vector2(7, -15)]),
				Color("f0dec1")
			)
			_draw_plaque(center + Vector2(0, -62), "You are here", Color("f0dec1"))
		elif not info["unlocked"]:
			_draw_lock(center + Vector2(0, -22))
		if not info["defined"] and size.x >= 700:
			_draw_plaque(center + Vector2(0, -55), "Not yet available", Color("c8b18c"))
		elif info["completed"] and size.x >= 700:
			_draw_plaque(center + Vector2(0, -55), "Completed", Color("9db777"))
	_draw_compass(Vector2(size.x - 28, 30))


func _draw_plaque(center: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	center.x = clampf(center.x, width / 2 + 5, maxf(width / 2 + 5, size.x - width / 2 - 5))
	draw_rect(Rect2(center - Vector2(width / 2 + 5, 12), Vector2(width + 10, 20)), Color("302016"))
	draw_string(
		font, center + Vector2(-width / 2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color
	)


func _draw_lock(center: Vector2) -> void:
	draw_style_box(
		get_theme_stylebox("normal", "Button"), Rect2(center - Vector2(13, 12), Vector2(26, 28))
	)
	draw_arc(center + Vector2(0, -3), 6, PI, TAU, 16, GOLD, 2, true)
	draw_rect(Rect2(center + Vector2(-7, -3), Vector2(14, 12)), GOLD)
	draw_circle(center + Vector2(0, 1), 2, Color("302016"))


func _draw_compass(center: Vector2) -> void:
	draw_line(center + Vector2(0, -12), center + Vector2(0, 12), GOLD, 1, true)
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), GOLD, 1, true)
	draw_string(
		get_theme_default_font(),
		center + Vector2(-4, -16),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		GOLD
	)
