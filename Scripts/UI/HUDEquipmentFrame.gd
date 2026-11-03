extends Control
## Reference-inspired equipment medallion and points/name plates, existing palette.


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var ink := Color("160f09")
	var gold := Color("ba9e6e")
	var panel := Color("341f12")
	for rect in [Rect2(54, 24, size.x - 58, 38), Rect2(64, 66, size.x - 68, 34)]:
		var points := PackedVector2Array(
			[
				rect.position,
				rect.position + Vector2(rect.size.x - 12, 0),
				rect.position + Vector2(rect.size.x, 12),
				rect.end - Vector2(12, 0),
				Vector2(rect.position.x, rect.end.y)
			]
		)
		draw_colored_polygon(points, panel)
		points.append(points[0])
		draw_polyline(points, ink, 8, false)
		draw_polyline(points, gold, 3, false)
	var center := Vector2(44, 56)
	draw_circle(center + Vector2(0, 3), 44, ink)
	draw_circle(center, 42, gold)
	draw_circle(center, 38, panel)
	# Small woven accent uses the shared moss and highlight colors.
	draw_line(Vector2(size.x - 20, 62), Vector2(size.x - 4, 50), Color("62791e"), 4, false)
