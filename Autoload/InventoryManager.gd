extends Node
## InventoryManager (Autoload Singleton)
##
## Tracks item counts the player holds. Item *definitions* (name, icon,
## description, category, stack limits, prices) live in
## Data/JSON/Item/*.json, owned by ItemDatabase (Phase 13 - Inventory &
## Shop) - this script never hardcodes item data, only counts, so adding
## a new item never requires editing this script. (This doc comment
## previously said definitions would live as .tres Resource files under
## Resources/Items/ - that was the original plan and was never built;
## JSON is what every other data system in this project actually uses,
## so item definitions follow that same convention now instead.)

# item_id -> int count
var _items: Dictionary = {}


func _ready() -> void:
	SaveManager.register_section("inventory", _get_save_data, _apply_save_data)


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	# Per-item stack limit via ItemDatabase (Phase 13) - any item_id with
	# no JSON definition yet falls back to ItemDatabase's own default
	# (999), so this is a no-op change in behavior for every item already
	# in use elsewhere in the project until you actually author a
	# definition for it.
	var max_stack: int = ItemDatabase.get_max_stack(item_id)
	_items[item_id] = min(_items.get(item_id, 0) + amount, max_stack)
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


## Item ids that no longer exist as real items. "coin" was a separate
## currency that existed briefly during Phase 13 before purchases were
## switched to the player's existing POINTS. A save made in that window
## could still contain it. It is DROPPED on load, deliberately NOT converted
## into points: coins and points were never defined to be equivalent, and
## converting would grant free points (which also feed DDAController's
## "Earned Points") for an arbitrary exchange rate.
const RETIRED_ITEM_IDS := ["coin"]


func _apply_save_data(data: Dictionary) -> void:
	_items = data.get("items", {})
	for retired_id in RETIRED_ITEM_IDS:
		if _items.has(retired_id):
			push_warning("InventoryManager: dropped %d retired '%s' from a loaded save (no longer an item; not converted to points)" % [int(_items[retired_id]), retired_id])
			_items.erase(retired_id)
	# Refresh any inventory display after a load - previously only add/remove
	# emitted this, so a UI built before the load kept showing stale counts.
	EventBus.inventory_changed.emit()
