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
var equipped_costume: String = ""


func _ready() -> void:
	SaveManager.register_section("inventory", _get_save_data, _apply_save_data)


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0 or item_id.is_empty():
		return
	var before := get_item_count(item_id)
	var added := mini(amount, maxi(0, ItemDatabase.get_max_stack(item_id) - before))
	if added == 0:
		return
	_items[item_id] = before + added
	EventBus.item_added.emit(item_id, added)
	EventBus.inventory_changed.emit()


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var current: int = _items.get(item_id, 0)
	if current < amount:
		return false
	_items[item_id] = current - amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
	if item_id == equipped_costume and not has_item(item_id):
		equipped_costume = ""
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
	return {"items": _items.duplicate(), "equipped_costume": equipped_costume}


## Item ids that no longer exist as real items. "coin" was a separate
## currency that existed briefly during Phase 13 before purchases were
## switched to the player's existing POINTS. A save made in that window
## could still contain it. It is DROPPED on load, deliberately NOT converted
## into points: coins and points were never defined to be equivalent, and
## converting would grant free points (which also feed DDAController's
## "Earned Points") for an arbitrary exchange rate.
const RETIRED_ITEM_IDS := ["coin"]


func _apply_save_data(data: Dictionary) -> void:
	_items = {}
	var loaded = data.get("items", {})
	if loaded is Dictionary:
		for key in loaded:
			if not key is String or key in RETIRED_ITEM_IDS:
				continue
			var value = loaded[key]
			if not (value is int or value is float) or not is_finite(float(value)):
				continue
			# Repair the old store's undefined rod without changing points.
			var item_id: String = "fishing_rod" if key == "basic rod" else key
			var count := clampi(int(value), 0, ItemDatabase.get_max_stack(item_id))
			if count > 0:
				_items[item_id] = mini(
					get_item_count(item_id) + count, ItemDatabase.get_max_stack(item_id)
				)
	equipped_costume = ""
	var costume = data.get("equipped_costume", "")
	if costume == "fisher_hat" and has_item(costume):
		equipped_costume = costume
	EventBus.inventory_changed.emit()


func toggle_costume(item_id: String) -> bool:
	if item_id != "fisher_hat" or not has_item(item_id):
		return false
	equipped_costume = "" if equipped_costume == item_id else item_id
	EventBus.inventory_changed.emit()
	return true
