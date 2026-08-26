extends Node
## InventoryManager (Autoload Singleton)
##
## Tracks item counts the player holds. Item *definitions* (name, icon,
## description, category) live as Resource files under Resources/Items/,
## keyed by item_id - this script never hardcodes item data, only counts,
## so adding a new item never requires editing this script.

# item_id -> int count
var _items: Dictionary = {}

const MAX_STACK_DEFAULT := 999


func _ready() -> void:
	SaveManager.register_section("inventory", _get_save_data, _apply_save_data)


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_items[item_id] = min(_items.get(item_id, 0) + amount, MAX_STACK_DEFAULT)
	EventBus.item_added.emit(item_id, amount)
	EventBus.inventory_changed.emit()


func remove_item(item_id: String, amount: int = 1) -> bool:
	var current: int = _items.get(item_id, 0)
	if current < amount:
		return false
	_items[item_id] = current - amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
	EventBus.item_removed.emit(item_id, amount)
	EventBus.inventory_changed.emit()
	return true


func get_item_count(item_id: String) -> int:
	return _items.get(item_id, 0)


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


func get_all_items() -> Dictionary:
	return _items.duplicate()


func _get_save_data() -> Dictionary:
	return {"items": _items}


func _apply_save_data(data: Dictionary) -> void:
	_items = data.get("items", {})
