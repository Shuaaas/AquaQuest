extends Control
## Original pixel-grid illustration, sharing the UI's sampled color palette.
## This is a regional overview, not a replacement for playable level geometry.

signal region_selected(region_id: String)

const ATLAS_SIZE := Vector2(960, 520)
const SEA := Color("3b535e")
const GOLD := Color("ba9e6e")

var selected_region_id: String = ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	EventBus.map_data_changed.connect(queue_redraw)


func _scale_factor() -> float:
	return minf(size.x / ATLAS_SIZE.x, size.y / ATLAS_SIZE.y)


func _offset() -> Vector2:
	return (size - ATLAS_SIZE * _scale_factor()) * 0.5


func get_region_screen_position(region_id: String) -> Vector2:
	for entry in MapManager.get_regions():
		if entry["region_id"] == region_id:
			return _offset() + _center(entry) * _scale_factor()
	return Vector2.ZERO


func _center(entry: Dictionary) -> Vector2:
	return Vector2(entry["position"][0], entry["position"][1]) * ATLAS_SIZE


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	pressed = pressed or event is InputEventScreenTouch
	if not pressed or not event.pressed:
		return
	for entry in MapManager.get_regions():
		if (
			get_region_screen_position(entry["region_id"]).distance_to(event.position)
			< 78 * _scale_factor()
		):
			region_selected.emit(entry["region_id"])
			accept_event()
			return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	var scale_value := _scale_factor()
	if scale_value <= 0:
		return
	draw_set_transform(_offset(), 0, Vector2.ONE * scale_value)
	_draw_water()
	var entries := MapManager.get_regions()
	for index in range(entries.size() - 1):
		_draw_route(_center(entries[index]), _center(entries[index + 1]))
	for index in range(entries.size()):
		_draw_island(entries[index], index)
	_draw_boat(Vector2(448, 213))
	draw_string(
		get_theme_default_font(),
		Vector2(22, 31),
		"A Q U A Q U E S T",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		19,
		GOLD
	)
	draw_string(
		get_theme_default_font(),
		Vector2(22, 493),
		"FIVE SHORES  /  ONE LEARNING JOURNEY",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color("8ac6e0")
	)
	_draw_compass(Vector2(897, 66))


func _draw_water() -> void:
	for row in range(12):
		for col in range(19):
			var origin := Vector2(col * 53 + posmod(row * 17, 29), row * 42 + 19)
			var tint := Color("4e6a75") if (row + col) % 3 else Color("5c8ea5")
			draw_rect(Rect2(origin, Vector2(13, 2)), tint)
			draw_rect(Rect2(origin + Vector2(13, -2), Vector2(5, 2)), tint)


func _draw_route(from: Vector2, to: Vector2) -> void:
	for step in range(2, 24):
		var weight := float(step) / 25
		var point := from.lerp(to, weight) + Vector2(0, sin(weight * PI) * 28)
		draw_rect(Rect2(point.snapped(Vector2(4, 4)), Vector2(4, 4)), Color("ba9e6e"))


func _draw_island(entry: Dictionary, index: int) -> void:
	var center := _center(entry)
	var grasses := [
		Color("62791e"), Color("475326"), Color("9f6c3f"), Color("5c8ea5"), Color("62791e")
	]
	for row in range(-13, 14):
		for col in range(-20, 21):
			var distance := pow(float(col) / 18, 2) + pow(float(row) / 11, 2)
			var irregularity := sin(col * 0.8 + index) * 0.055 + cos(row * 1.3) * 0.045
			if distance > 1.18 + irregularity:
				continue
			var tint := Color("5c8ea5")
			if distance < 1.02 + irregularity:
				tint = Color("ba9e6e")
			if distance < 0.79 + irregularity:
				tint = grasses[index % grasses.size()]
				if posmod(col * 17 + row * 31 + index * 79, 23) < 3:
					tint = tint.lightened(0.06)
			draw_rect(Rect2(center + Vector2(col, row) * 4, Vector2(4, 4)), tint)
	_draw_details(center, entry["theme"])
	var info := MapManager.get_region_info(entry["region_id"])
	var tint := GOLD if info["unlocked"] else Color("847c71")
	if info["current"]:
		tint = Color("8ac6e0")
	elif info["completed"]:
		tint = Color("62791e")
	if selected_region_id == entry["region_id"]:
		draw_rect(Rect2(center - Vector2(83, 61), Vector2(166, 122)), GOLD, false, 2)
	var label_position := center + Vector2(-60, 69)
	draw_rect(Rect2(label_position - Vector2(3, 15), Vector2(128, 24)), Color("341f12"))
	var number: String = entry["region_id"].trim_prefix("region_")
	var module: String = entry["module_id"].trim_prefix("module_")
	draw_string(
		get_theme_default_font(),
		label_position,
		"R%s / MODULE %s" % [number, module],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		tint
	)
	if not info["unlocked"]:
		_draw_lock(center + Vector2(49, -30))
	elif info["current"]:
		draw_colored_polygon(
			PackedVector2Array(
				[center + Vector2(-6, -65), center + Vector2(6, -65), center + Vector2(0, -55)]
			),
			tint
		)
	elif info["completed"]:
		draw_polyline(
			PackedVector2Array(
				[center + Vector2(42, -34), center + Vector2(48, -28), center + Vector2(59, -42)]
			),
			tint,
			4
		)


func _draw_details(center: Vector2, theme: String) -> void:
	# River, paths, docks, sheds and reefs are illustrative landscape motifs.
	if theme == "wetland":
		for step in range(-9, 10):
			draw_rect(
				Rect2(center + Vector2(sin(step * 0.4) * 15 - 6, step * 4), Vector2(12, 5)),
				Color("8ac6e0")
			)
	else:
		draw_rect(Rect2(center + Vector2(-47, 5), Vector2(94, 6)), Color("ba9e6e"))
	_draw_house(
		center + Vector2(-27, -14), Color("7d4c28") if theme != "preservation" else Color("5c8ea5")
	)
	_draw_house(
		center + Vector2(18, 7), Color("a06131") if theme != "archipelago" else Color("ba9e6e")
	)
	for index in range(4):
		var offset := Vector2(-49 + index * 28, -28 - posmod(index * 13, 17))
		_draw_tree_icon(center + offset, theme)
	for plank in range(7):
		draw_rect(Rect2(center + Vector2(39 + plank * 5, 18), Vector2(4, 11)), Color("7d4c28"))
	if theme == "curing":
		for rack in range(3):
			var origin := center + Vector2(-27 + rack * 18, 24)
			draw_rect(Rect2(origin, Vector2(12, 3)), Color("5a361e"))
			draw_rect(Rect2(origin + Vector2(0, 3), Vector2(2, 10)), Color("5a361e"))
			for fish in range(3):
				draw_rect(Rect2(origin + Vector2(fish * 4, 4), Vector2(2, 6)), Color("ddccb8"))
	elif theme == "preservation":
		for box in range(4):
			draw_rect(Rect2(center + Vector2(-42 + box * 16, 25), Vector2(12, 9)), Color("cbe0e8"))
	elif theme == "archipelago":
		for island in range(3):
			draw_rect(
				Rect2(center + Vector2(-61 + island * 30, 37), Vector2(16, 7)), Color("ba9e6e")
			)
	elif theme == "village":
		_draw_boat(center + Vector2(61, 31))


func _draw_house(origin: Vector2, roof: Color) -> void:
	draw_rect(Rect2(origin + Vector2(-11, 0), Vector2(22, 15)), Color("ba9e6e"))
	draw_rect(Rect2(origin + Vector2(-15, -8), Vector2(30, 10)), roof)
	draw_rect(Rect2(origin + Vector2(-10, -12), Vector2(20, 4)), roof.lightened(0.1))
	draw_rect(Rect2(origin + Vector2(-2, 5), Vector2(5, 10)), Color("160f09"))


func _draw_tree_icon(origin: Vector2, theme: String) -> void:
	# Newly drawn map symbol. No environmental texture or sprite is sampled.
	var shade := Color("475326")
	var light := Color("62791e")
	if theme == "preservation":
		shade = Color("5c8ea5")
		light = Color("8ac6e0")
	elif theme == "curing":
		shade = Color("7d4c28")
		light = Color("a06131")
	draw_rect(Rect2(origin + Vector2(7, 16), Vector2(5, 14)), Color("160f09"))
	draw_rect(Rect2(origin + Vector2(8, 16), Vector2(3, 12)), Color("7d4c28"))
	draw_rect(Rect2(origin + Vector2(4, 0), Vector2(11, 22)), Color("160f09"))
	draw_rect(Rect2(origin + Vector2(1, 5), Vector2(17, 12)), Color("160f09"))
	draw_rect(Rect2(origin + Vector2(5, 2), Vector2(9, 18)), shade)
	draw_rect(Rect2(origin + Vector2(3, 6), Vector2(13, 9)), shade)
	draw_rect(Rect2(origin + Vector2(5, 3), Vector2(5, 10)), light)
	draw_rect(Rect2(origin + Vector2(4, 7), Vector2(3, 4)), light)


func _draw_boat(origin: Vector2) -> void:
	draw_rect(Rect2(origin, Vector2(19, 6)), Color("a06131"))
	draw_rect(Rect2(origin + Vector2(4, 6), Vector2(12, 3)), Color("5a361e"))
	draw_rect(Rect2(origin + Vector2(9, -15), Vector2(2, 16)), Color("ba9e6e"))
	draw_colored_polygon(
		PackedVector2Array(
			[origin + Vector2(11, -15), origin + Vector2(11, -2), origin + Vector2(20, -2)]
		),
		Color("ddccb8")
	)


func _draw_lock(origin: Vector2) -> void:
	draw_rect(Rect2(origin, Vector2(14, 12)), Color("160f09"))
	draw_rect(Rect2(origin + Vector2(3, -6), Vector2(8, 7)), GOLD, false, 2)
	draw_rect(Rect2(origin + Vector2(6, 4), Vector2(2, 5)), GOLD)


func _draw_compass(origin: Vector2) -> void:
	draw_line(origin + Vector2(0, -18), origin + Vector2(0, 18), GOLD, 2)
	draw_line(origin + Vector2(-18, 0), origin + Vector2(18, 0), GOLD, 2)
	draw_colored_polygon(
		PackedVector2Array(
			[origin + Vector2(0, -18), origin + Vector2(-5, 0), origin + Vector2(5, 0)]
		),
		GOLD
	)
	draw_string(
		get_theme_default_font(),
		origin + Vector2(-5, -24),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		GOLD
	)
