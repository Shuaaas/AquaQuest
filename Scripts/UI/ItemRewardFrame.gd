extends Control
## Smooth icon medallion; the wood card and parchment remain editable scene controls.
var stars: int = 1:
	set(value):
		stars = clampi(value, 1, 4)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 40)
	draw_circle(center + Vector2(0, 3), 43, Color("21160f"), true, -1, true)
	draw_circle(center, 42, Color("76502f"), true, -1, true)
	draw_circle(center, 39, Color("c6a66a"), true, -1, true)
	draw_circle(center, 36, Color("987044"), true, -1, true)
	draw_circle(center + Vector2(0, 1), 33, Color("4a3020"), true, -1, true)
