extends Node
## ShopManager (Autoload Singleton)
##
## Single responsibility: run shop purchases and track per-shop stock and
## one-time-purchase history. Consumes the shop hooks that have existed on
## EventBus since the NPC System phase: shop_opened, shop_closed,
## item_purchased (item_sold is no longer emitted - see SELLING below).
##
## CURRENCY = THE PLAYER'S EXISTING POINTS (Phase 13 fix). This script used
## to charge a separate "coin" item. That was wrong: your thesis defines a
## Reward System where players spend the points they EARN through correct
## answers. Points now come from FishingManager, which has always owned
## the balance (_points) - this script never keeps its own copy and never
## writes the balance directly. It only calls FishingManager.can_afford()
## and FishingManager.spend_points(), the single entry point for spending.
##
## HOW A MERCHANT OPENS A SHOP: unchanged. NPCManager's "open_shop" action
## emits EventBus.shop_opened(merchant_node); this script reads
## merchant.shop_id off that node to pick a Data/JSON/Shops/*.json catalog.
##
## PURCHASE TRANSACTION (buy_item) - validate everything, then commit:
##   1. one-time item already owned/purchased?   -> refuse
##   2. limited stock exhausted?                 -> refuse
##   3. already at the item's max_stack?         -> refuse (no charge)
##   4. can the player afford the points cost?   -> refuse (no change)
##   5. add the item; verify the count actually rose (else: no charge)
##   6. spend the points (rolls the item back if that somehow fails)
##   7. record stock / one-time history, emit item_purchased, notify
## There are no awaits anywhere in that sequence, so it runs start to
## finish before the next button press can be processed - rapid clicking
## cannot double-charge or double-grant, because each click re-runs the
## full validation against the already-updated state.
##
## SELLING IS DISABLED (a decision for you to approve - see
## is_selling_enabled()). Selling used to pay coins. Paying POINTS for
## selling would let a player raise their balance without answering any
## question, and DDAController counts every positive points change as
## "Earned Points" (the AQPI P term), so sale proceeds would silently
## distort your difficulty-adjustment inputs. Your thesis does not define
## selling, so it is switched off rather than guessed at.
##
## DATA LOCATION: Data/JSON/Shops/*.json
## EXPECTED JSON SHAPE:
##   {
##     "shop_id": "general_store",
##     "items_for_sale": [
##       { "item_id": "energy_bait", "stock": -1 },
##       { "item_id": "fisher_hat", "stock": 1, "price_override": 40 }
##     ]
##   }
## `stock` of -1 (or omitted) means unlimited. `price_override` (in POINTS)
## is optional - without it, ItemDatabase.get_buy_price(item_id) is used.

const SHOPS_JSON_DIR := "res://Data/JSON/Shops/"

# shop_id -> shop definition Dictionary
var _shop_definitions: Dictionary = {}

# shop_id -> {item_id -> remaining stock int}, only for limited-stock items.
# Persisted so stock doesn't silently reset every time the game restarts.
var _remaining_stock: Dictionary = {}

# item_id -> true, for every one-time item ever bought. Persisted, so a
# one-time item can't be re-bought after a reload, or after being lost/
# removed from the inventory.
var _purchased_one_time: Dictionary = {}

var _current_shop_id: String = ""


func _ready() -> void:
	_load_all_shops()
	EventBus.shop_opened.connect(_on_shop_opened)
	SaveManager.register_section("shop_stock", _get_save_data, _apply_save_data)


func _load_all_shops() -> void:
	var dir := DirAccess.open(SHOPS_JSON_DIR)
	if dir == null:
		push_warning("ShopManager: no Shops JSON directory found yet at %s" % SHOPS_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open(SHOPS_JSON_DIR + file_name, FileAccess.READ)
			if file == null:
				file_name = dir.get_next()
				continue
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("shop_id"):
				_shop_definitions[parsed["shop_id"]] = parsed
				_init_stock_for_shop(parsed)
			else:
				push_warning("ShopManager: %s missing required field 'shop_id'" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _init_stock_for_shop(shop_def: Dictionary) -> void:
	var shop_id: String = shop_def["shop_id"]
	if _remaining_stock.has(shop_id):
		return  # already initialized (e.g. restored from a save)
	var stock_map: Dictionary = {}
	for entry in shop_def.get("items_for_sale", []):
		var stock: int = int(entry.get("stock", -1))
		if stock >= 0:
			stock_map[entry.get("item_id", "")] = stock
	_remaining_stock[shop_id] = stock_map


func _on_shop_opened(merchant: Node) -> void:
	var shop_id: String = ""
	if merchant is NPC:
		shop_id = merchant.shop_id

	if shop_id == "" or not _shop_definitions.has(shop_id):
		push_error("ShopManager: shop_opened fired but no valid shop_id found on merchant node")
		return

	_current_shop_id = shop_id
	EventBus.shop_catalog_ready.emit(shop_id, _build_catalog_view(shop_id))


## Resolves each catalog entry's display info into one Dictionary per item,
## ready for ShopUI to render without calling ItemDatabase itself. "price"
## is in POINTS. "already_purchased" is true for a one-time item the player
## owns or has bought before, so the UI can show it as unavailable.
func _build_catalog_view(shop_id: String) -> Array:
	var shop_def: Dictionary = _shop_definitions[shop_id]
	var stock_map: Dictionary = _remaining_stock.get(shop_id, {})
	var catalog: Array = []

	for entry in shop_def.get("items_for_sale", []):
		var item_id: String = entry.get("item_id", "")
		var price: int = int(entry.get("price_override", ItemDatabase.get_buy_price(item_id)))
		var stock: int = int(stock_map.get(item_id, -1)) if int(entry.get("stock", -1)) >= 0 else -1
		var one_time := ItemDatabase.is_one_time_purchase(item_id)

		catalog.append({
			"item_id": item_id,
			"display_name": ItemDatabase.get_display_name(item_id),
			"price": price,
			"stock": stock,  # -1 = unlimited
			"already_purchased": one_time and (_purchased_one_time.has(item_id) or InventoryManager.has_item(item_id)),
		})

	return catalog


## Public - lets ShopUI refresh its displayed catalog (e.g. after a
## purchase changes remaining stock) without reaching into private state.
func get_current_catalog() -> Array:
	if _current_shop_id == "":
		return []
	return _build_catalog_view(_current_shop_id)


func close_shop() -> void:
	_current_shop_id = ""
	EventBus.shop_closed.emit()


## Called by ShopUI. Returns true only if the purchase fully completed.
## Always buys exactly 1 unit per call. See the class doc for the full
## validate-then-commit sequence and why rapid clicks are safe.
func buy_item(item_id: String) -> bool:
	if _current_shop_id == "":
		push_warning("ShopManager: buy_item called with no shop open")
		return false

	var shop_def: Dictionary = _shop_definitions[_current_shop_id]
	var entry := _find_catalog_entry(shop_def, item_id)
	if entry.is_empty():
		push_warning("ShopManager: '%s' is not sold in this shop" % item_id)
		return false

	var display_name := ItemDatabase.get_display_name(item_id)
	var one_time := ItemDatabase.is_one_time_purchase(item_id)

	# 1. One-time items: refuse if bought before OR currently owned.
	if one_time and (_purchased_one_time.has(item_id) or InventoryManager.has_item(item_id)):
		UIManager.show_notification("You already own %s." % display_name, 2.0)
		return false

	# 2. Limited stock.
	var stock_map: Dictionary = _remaining_stock.get(_current_shop_id, {})
	if stock_map.has(item_id) and int(stock_map[item_id]) <= 0:
		UIManager.show_notification("%s is out of stock." % display_name, 2.0)
		return false

	# 3. Inventory capacity (per-item max_stack). Checked BEFORE charging so
	# the player can never pay for an item that then fails to be added.
	var owned_before := InventoryManager.get_item_count(item_id)
	if owned_before >= ItemDatabase.get_max_stack(item_id):
		UIManager.show_notification("You can't carry any more %s." % display_name, 2.0)
		return false

	# 4. Affordability - against the player's existing points balance.
	var price: int = int(entry.get("price_override", ItemDatabase.get_buy_price(item_id)))
	if not FishingManager.can_afford(price):
		UIManager.show_notification(
			"Not enough points. %s costs %d, you have %d." % [display_name, price, FishingManager.get_points()], 2.5)
		return false

	# 5. Commit: add the item and VERIFY it landed before any points move.
	InventoryManager.add_item(item_id, 1)
	if InventoryManager.get_item_count(item_id) <= owned_before:
		UIManager.show_notification("Couldn't add %s to your inventory. You were not charged." % display_name, 2.5)
		return false

	# 6. Spend. Pre-validated above, so a failure here should be impossible -
	# but if it ever happens, undo the grant rather than give the item free.
	if not FishingManager.spend_points(price):
		InventoryManager.remove_item(item_id, 1)
		UIManager.show_notification("Purchase failed. You were not charged.", 2.5)
		return false

	# 7. Bookkeeping + feedback.
	if stock_map.has(item_id):
		stock_map[item_id] = int(stock_map[item_id]) - 1
		_remaining_stock[_current_shop_id] = stock_map
	if one_time:
		_purchased_one_time[item_id] = true

	# item_purchased(item_id, price) - signature unchanged since the NPC
	# System phase. "price" is the points paid for this 1-unit purchase.
	EventBus.item_purchased.emit(item_id, price)
	UIManager.show_notification("Purchased %s for %d points!" % [display_name, price], 2.0)
	return true


## Selling is switched off - see the class doc for why. To turn it on you
## would need to decide how sale proceeds are credited WITHOUT being
## counted as "Earned Points" by DDAController (it counts every positive
## fishing_points_changed delta), which means a deliberate change on the
## DDA side. That is your call, not something to guess at here.
func is_selling_enabled() -> bool:
	return false


func sell_item(_item_id: String) -> bool:
	UIManager.show_notification("Selling isn't available.", 2.0)
	return false


func _find_catalog_entry(shop_def: Dictionary, item_id: String) -> Dictionary:
	for entry in shop_def.get("items_for_sale", []):
		if entry.get("item_id", "") == item_id:
			return entry
	return {}


func _get_save_data() -> Dictionary:
	return {
		"remaining_stock": _remaining_stock,
		"purchased_one_time": _purchased_one_time,
	}


func _apply_save_data(data: Dictionary) -> void:
	# Normalize stock back to ints - JSON round-trips whole numbers as floats.
	var loaded_stock: Dictionary = data.get("remaining_stock", {})
	_remaining_stock = {}
	for shop_id in loaded_stock:
		var stock_map: Dictionary = {}
		for item_id in loaded_stock[shop_id]:
			stock_map[item_id] = int(loaded_stock[shop_id][item_id])
		_remaining_stock[shop_id] = stock_map
	# Older saves have no "purchased_one_time" key - treated as empty.
	_purchased_one_time = data.get("purchased_one_time", {})
