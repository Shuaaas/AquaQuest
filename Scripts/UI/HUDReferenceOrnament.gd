@tool
extends Control
## Purely decorative chrome drawn above the existing live minimap or wood panel.
const STYLE := preload("res://Scripts/UI/HUDReferenceStyle.gd")
@export var ring := false
@export var wood_knot := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if ring:
		var center := size / 2
		var radius := minf(size.x, size.y) / 2 - 2
		draw_arc(center + Vector2(0, 3), radius, 0, TAU, 96, STYLE.SHADOW, 6, true)
		draw_arc(center, radius, 0, TAU, 96, STYLE.WOOD.darkened(0.25), 4, true)
		draw_arc(center, radius - 2, 0, TAU, 96, STYLE.GOLD.lerp(STYLE.LIGHT_WOOD, 0.25), 3, true)
		draw_arc(center, radius - 5, 0, TAU, 96, STYLE.LIGHT_WOOD, 3, true)
		draw_arc(center, radius - 7, 0, TAU, 96, STYLE.WOOD.darkened(0.15), 1, true)
	elif wood_knot:
		draw_texture_rect(STYLE.KNOT, Rect2(size.x - 10, 14, 22, 22), false)
	else:
		var leaves := STYLE.LEAVES
		draw_texture_rect(leaves, Rect2(size.x - 16, -2, 24, 24), false)
		draw_texture_rect(leaves, Rect2(size.x - 14, size.y - 21, 20, 20), false)
