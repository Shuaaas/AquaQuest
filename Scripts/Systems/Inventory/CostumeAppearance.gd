extends Node2D
## Original pixel hat overlay. Cosmetic only; no physics or score effects.


func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = InventoryManager.equipped_costume == "fisher_hat"
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-9, -4, 18, 7), Color("160f09"))
	draw_rect(Rect2(-6, -8, 12, 8), Color("160f09"))
	draw_rect(Rect2(-5, -7, 10, 6), Color("ba9e6e"))
	draw_rect(Rect2(-5, -2, 10, 2), Color("7d4c28"))
	draw_rect(Rect2(-8, 0, 16, 2), Color("ddccb8"))
