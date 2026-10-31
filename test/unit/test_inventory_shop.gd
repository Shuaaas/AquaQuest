extends GutTest

const INVENTORY := preload("res://Scene/UI/inventory_ui.tscn")
const SHOP := preload("res://Scene/UI/shop_ui.tscn")
const PLAYER := preload("res://test/fixtures/save_region.tscn")
var inventory_before: Dictionary
var shop_before: Dictionary
var points_before: Dictionary
var definitions_before: Dictionary
var current_before: String
var game_state: int
var dda_before: Dictionary


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_before = InventoryManager._get_save_data().duplicate(true)
	shop_before = ShopManager._get_save_data().duplicate(true)
	points_before = FishingManager._get_points_save_data().duplicate(true)
	definitions_before = ShopManager._shop_definitions.duplicate(true)
	current_before = ShopManager._current_shop_id
	game_state = GameManager.current_state
	dda_before = DDAController._get_save_data().duplicate(true)
	InventoryManager._apply_save_data({})
	ShopManager._apply_save_data({})
	FishingManager._apply_points_save_data({"points": 100, "total_earned": 100, "total_spent": 0})
	ShopManager._current_shop_id = "general_store"
	GameManager.current_state = GameManager.GameState.PLAYING


func after_each() -> void:
	GameManager.set_paused(false)
	for child in get_children():
		if child is InventoryUI:
			child.close_inventory()
		if child is ShopUI:
			child._on_shop_closed()
	InventoryManager._apply_save_data(inventory_before)
	ShopManager._shop_definitions = definitions_before
	ShopManager._apply_save_data(shop_before)
	ShopManager._current_shop_id = current_before
	FishingManager._apply_points_save_data(points_before)
	DDAController._apply_save_data(dda_before)
	GameManager.current_state = game_state
	await get_tree().process_frame


func test_catalog_uses_defined_items_and_existing_icons() -> void:
	for entry in ShopManager.get_current_catalog():
		assert_true(ItemDatabase.has_definition(entry.item_id))
	for item_id in ItemDatabase.get_all_item_ids():
		assert_true(ResourceLoader.exists(ItemDatabase.get_icon_path(item_id)), item_id)


func test_buy_real_rod_charges_once_and_unlocks_existing_equip_path() -> void:
	var region := PLAYER.instantiate()
	add_child_autofree(region)
	assert_true(ShopManager.buy_item("fishing_rod"))
	assert_eq(FishingManager.get_points(), 90)
	assert_eq(InventoryManager.get_item_count("fishing_rod"), 1)
	region.get_node("player").fishing_rod.toggle()
	assert_true(region.get_node("player").fishing_rod.is_equipped())
	assert_false(ShopManager.buy_item("fishing_rod"))
	assert_eq(FishingManager.get_points(), 90)
	assert_eq(FishingManager.get_total_points_earned(), 100)
	assert_eq(FishingManager.get_total_points_spent(), 10)


func test_failed_purchase_never_changes_points_inventory_or_stock() -> void:
	FishingManager._apply_points_save_data({"points": 0})
	var stock := ShopManager._get_save_data().duplicate(true)
	assert_false(ShopManager.buy_item("fishing_rod"))
	assert_false(ShopManager.buy_item("undefined"))
	assert_false(ShopManager.buy_item("fishing_rod", -1))
	assert_false(ShopManager.buy_item("fishing_rod", 0))
	assert_eq(InventoryManager.get_all_items(), {})
	assert_eq(ShopManager._get_save_data(), stock)
	assert_eq(FishingManager.get_points(), 0)


func test_bulk_purchase_is_all_or_nothing() -> void:
	# Fixture only: bait is not added to the production catalog without an effect.
	ShopManager._shop_definitions["general_store"].items_for_sale.append(
		{"item_id": "energy_bait", "stock": 10}
	)
	ShopManager._remaining_stock["general_store"]["energy_bait"] = 10
	assert_true(ShopManager.buy_item("energy_bait", 3))
	assert_eq(InventoryManager.get_item_count("energy_bait"), 3)
	assert_eq(FishingManager.get_points(), 70)
	assert_false(ShopManager.buy_item("energy_bait", 8))
	assert_eq(InventoryManager.get_item_count("energy_bait"), 3)
	assert_eq(ShopManager._remaining_stock.general_store.energy_bait, 7)
	assert_eq(FishingManager.get_points(), 70)


func test_full_inventory_rejects_purchase_without_charge() -> void:
	InventoryManager.add_item("fishing_rod")
	assert_eq(ShopManager.purchase_error("fishing_rod"), "Inventory stack full.")
	assert_false(ShopManager.buy_item("fishing_rod"))
	assert_eq(FishingManager.get_points(), 100)


func test_hat_history_inventory_and_stock_survive_json_round_trip() -> void:
	assert_true(ShopManager.buy_item("fisher_hat"))
	assert_true(InventoryManager.toggle_costume("fisher_hat"))
	var inventory = JSON.parse_string(JSON.stringify(InventoryManager._get_save_data()))
	var shop = JSON.parse_string(JSON.stringify(ShopManager._get_save_data()))
	InventoryManager._apply_save_data({})
	ShopManager._apply_save_data({})
	InventoryManager._apply_save_data(inventory)
	ShopManager._apply_save_data(shop)
	assert_eq(InventoryManager.equipped_costume, "fisher_hat")
	InventoryManager.remove_item("fisher_hat")
	assert_eq(InventoryManager.equipped_costume, "")
	assert_false(ShopManager.buy_item("fisher_hat"))
	assert_eq(FishingManager.get_points(), 50)


func test_invalid_quantities_and_overflow_emit_only_actual_grants() -> void:
	assert_false(InventoryManager.remove_item("fish", -5))
	assert_false(InventoryManager.remove_item("fish", 0))
	InventoryManager.add_item("energy_bait", 19)
	watch_signals(EventBus)
	InventoryManager.add_item("energy_bait", 10)
	assert_signal_emitted_with_parameters(EventBus, "item_added", ["energy_bait", 1])
	assert_eq(InventoryManager.get_item_count("energy_bait"), 20)


func test_load_repairs_legacy_rod_and_clamps_bad_counts() -> void:
	InventoryManager._apply_save_data(
		{
			"items":
			{"basic rod": 1, "fishing_rod": 1, "energy_bait": 1000, "fish": -3, "tilapia": "bad"}
		}
	)
	assert_eq(InventoryManager.get_all_items(), {"fishing_rod": 1, "energy_bait": 20})
	ShopManager._apply_save_data({"remaining_stock": {"general_store": {"basic rod": 0}}})
	assert_eq(ShopManager._remaining_stock.general_store.fishing_rod, 0)
	assert_eq(ShopManager._remaining_stock.general_store.fisher_hat, 1)


func test_inventory_filters_sorting_and_pause_safe_close() -> void:
	InventoryManager.add_item("fishing_rod")
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	assert_true(ui.open_inventory())
	assert_true(get_tree().paused)
	ui._on_filter_pressed("item")
	assert_eq(ui.item_list_container.get_child_count(), 1)
	ui._on_filter_pressed("costume")
	assert_eq(ui.item_list_container.get_child(0).text, "No items in this category.")
	ui.set_sort_mode("quantity")
	assert_eq(ui.get_node("%SortList").selected, 2)
	ui.close_inventory()
	assert_false(get_tree().paused)


func test_inventory_refuses_foreign_pause_and_shop_disables_unaffordable_buy() -> void:
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	GameManager.set_paused(true)
	assert_false(ui.open_inventory())
	ui.close_inventory()
	assert_true(get_tree().paused)
	GameManager.set_paused(false)
	var shop := SHOP.instantiate()
	add_child_autofree(shop)
	FishingManager._apply_points_save_data({"points": 0})
	shop._on_catalog_ready("general_store", ShopManager.get_current_catalog())
	assert_true(shop._controls.fishing_rod.buy.disabled)
	assert_eq(shop._controls.fishing_rod.status.text, "Not enough points.")
	shop._on_close_pressed()
	assert_false(get_tree().paused)


func test_cosmetic_overlay_and_removed_rod_follow_inventory() -> void:
	var region := PLAYER.instantiate()
	add_child_autofree(region)
	var player = region.get_node("player")
	InventoryManager.add_item("fisher_hat")
	InventoryManager.toggle_costume("fisher_hat")
	assert_true(player.get_node("CostumeAppearance").visible)
	InventoryManager.add_item("fishing_rod")
	player.fishing_rod.toggle()
	InventoryManager.remove_item("fishing_rod")
	assert_false(player.fishing_rod.is_equipped())


func test_real_save_reload_preserves_purchase_equipment_and_points() -> void:
	var sections := SaveManager._registered_sections.duplicate()
	var slot := 1000000000 + randi_range(0, 1000000000)
	while SaveManager.slot_exists(slot):
		slot += 1
	SaveManager._registered_sections = []
	SaveManager.register_section(
		"inventory", InventoryManager._get_save_data, InventoryManager._apply_save_data
	)
	SaveManager.register_section(
		"shop_stock", ShopManager._get_save_data, ShopManager._apply_save_data
	)
	SaveManager.register_section(
		"points", FishingManager._get_points_save_data, FishingManager._apply_points_save_data
	)
	assert_true(ShopManager.buy_item("fisher_hat"))
	InventoryManager.toggle_costume("fisher_hat")
	assert_true(SaveManager.save_game(slot))
	InventoryManager._apply_save_data({})
	ShopManager._apply_save_data({})
	FishingManager._apply_points_save_data({})
	assert_true(await SaveManager.load_game(slot))
	assert_eq(InventoryManager.get_item_count("fisher_hat"), 1)
	assert_eq(InventoryManager.equipped_costume, "fisher_hat")
	assert_eq(FishingManager.get_points(), 50)
	assert_false(ShopManager.buy_item("fisher_hat"))
	SaveManager._registered_sections = sections
	DirAccess.remove_absolute(SaveManager._slot_path(slot))


func test_reentrant_purchase_cannot_charge_twice() -> void:
	var nested: Array = []
	var listener := func(_points: int, delta: int):
		if delta < 0:
			nested.append(ShopManager.buy_item("fishing_rod"))
	EventBus.fishing_points_changed.connect(listener)
	assert_true(ShopManager.buy_item("fishing_rod"))
	EventBus.fishing_points_changed.disconnect(listener)
	assert_eq(nested, [false])
	assert_eq(FishingManager.get_points(), 90)
	assert_eq(InventoryManager.get_item_count("fishing_rod"), 1)
