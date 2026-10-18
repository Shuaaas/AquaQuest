extends Node
## ItemDatabase (Autoload Singleton)
##
## Single responsibility: know what an item IS - its display name,
## category, icon, stack limit, and shop prices. It does not track how
## many of anything the player HAS (InventoryManager's job, unchanged)
## and does not run shop transactions (ShopManager's job). This is the
## same data/logic split as QuestionManager vs FishingManager, or
## RegionManager's definitions vs RegionManager's own travel logic.
##
## REPLACES a never-built plan: InventoryManager's original doc comment
## said item definitions would live as .tres Resource files under
## Resources/Items/ - that was never actually implemented. This project
## has consistently used JSON for every other data system since
## (Questions, Regions, NPCs, Quests, Exams, Fishing Areas), so item
## definitions follow the same convention here instead, for consistency
## and because nothing else in the project needs the Resource editor.
##
## DATA LOCATION: Data/JSON/Items/*.json, each file an array of item
## definitions (same shape as Data/JSON/Questions/*.json).
##
## EXPECTED JSON SHAPE:
##   [
##     {
##       "item_id": "fishing_rod",
##       "display_name": "Fishing Rod",
##       "description": "A sturdy rod for catching fish.",
##       "category": "item",
##       "icon": "res://Assets/Icons/fishing_rod.png",
##       "max_stack": 1,
##       "sellable": false,
##       "buy_price": 0,
##       "sell_price": 0
##     }
##   ]
##
## CATEGORIES (the "Support" list from the brief): "item" (generic/misc,
## the default for any item with no category set), "quest_item",
## "consumable", "costume", "material" (for future crafting - see
## FUTURE CRAFTING COMPATIBILITY below). "Rewards" from the brief isn't a
## category - any item can be a reward, since every reward-granting
## system (NPCManager's give_item action, FishingManager's catch reward,
## QuestObjectiveManager's quest reward) already just calls
## InventoryManager.add_item() regardless of category.
##
## PRICES ARE POINTS (Phase 13 fix): buy_price is the number of the player's
## existing POINTS (the same balance FishingManager already tracks for
## correct/incorrect answers) an item costs. There is no separate currency.
## sell_price is retained in the schema but currently unused - see
## ShopManager.SELLING_ENABLED for why selling is switched off.
##
## ONE-TIME PURCHASES: an item can be bought at most once ever if
## "one_time_purchase": true. Costumes default to one-time even when the
## key is omitted (see is_one_time_purchase), the same way quest items
## default to unsellable.
##
## DEFAULTS for an item with no JSON definition at all (keeps every
## item_id already used elsewhere in the project - "fish", "tilapia",
## "explorer_badge", etc. - working exactly as before, undefined items
## just behave generically):
##   display_name = item_id, category = "item", max_stack = 999,
##   sellable = true, buy_price = 0 (not purchasable), sell_price = 0
##
## FUTURE CRAFTING COMPATIBILITY: the "material" category and this
## data-driven schema are deliberately ready for a future CraftingManager
## (recipes referencing item_ids, same JSON-array-of-definitions pattern)
## - no crafting logic exists yet, this just doesn't block it later.

const ITEMS_JSON_DIR := "res://Data/JSON/Items/"
const DEFAULT_MAX_STACK := 999

# item_id -> item definition Dictionary
var _item_definitions: Dictionary = {}


func _ready() -> void:
	var dir := DirAccess.open(ITEMS_JSON_DIR)
	if dir == null:
		push_warning("ItemDatabase: no Items JSON directory found yet at %s" % ITEMS_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_item_file(ITEMS_JSON_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_item_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		push_warning("ItemDatabase: expected a JSON array in %s" % path)
		return

	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("item_id"):
			_item_definitions[entry["item_id"]] = entry
		else:
			push_warning("ItemDatabase: an entry in %s is missing 'item_id'" % path)


func get_item_definition(item_id: String) -> Dictionary:
	return _item_definitions.get(item_id, {})


func has_definition(item_id: String) -> bool:
	return _item_definitions.has(item_id)


func get_display_name(item_id: String) -> String:
	return get_item_definition(item_id).get("display_name", item_id)


func get_description(item_id: String) -> String:
	return get_item_definition(item_id).get("description", "")


func get_category(item_id: String) -> String:
	return get_item_definition(item_id).get("category", "item")


func get_icon_path(item_id: String) -> String:
	return get_item_definition(item_id).get("icon", "")


func get_max_stack(item_id: String) -> int:
	return get_item_definition(item_id).get("max_stack", DEFAULT_MAX_STACK)


## Quest items default to NOT sellable even if "sellable" is omitted from
## their JSON - a sensible per-category default so a content author
## doesn't have to remember to set sellable:false on every quest item.
## Any item can still override this explicitly either direction.
func is_sellable(item_id: String) -> bool:
	var def := get_item_definition(item_id)
	if def.has("sellable"):
		return def.get("sellable")
	return get_category(item_id) != "quest_item"


## Costumes are cosmetic unlocks, so they default to one-time purchase unless
## the item explicitly sets "one_time_purchase": false.
func is_one_time_purchase(item_id: String) -> bool:
	var def := get_item_definition(item_id)
	if def.has("one_time_purchase"):
		return def.get("one_time_purchase")
	return get_category(item_id) == "costume"


## Cost in POINTS (not coins - there is no coin currency).
func get_buy_price(item_id: String) -> int:
	return get_item_definition(item_id).get("buy_price", 0)


func get_sell_price(item_id: String) -> int:
	return get_item_definition(item_id).get("sell_price", 0)


## For UI filtering - returns every known item_id in a category, in no
## particular order (callers sort as needed for display).
func get_item_ids_by_category(category: String) -> Array:
	var result: Array = []
	for item_id in _item_definitions:
		if get_category(item_id) == category:
			result.append(item_id)
	return result


func get_all_item_ids() -> Array:
	return _item_definitions.keys()
