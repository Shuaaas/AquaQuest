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
	assert_eq(ui._slot_buttons.size(), 1)
	assert_eq(ui.item_list_container.get_child_count(), 12)
	ui._on_filter_pressed("costume")
	assert_eq(ui.get_node("%EmptyMessage").text, "No items in this category.")
	assert_true(ui.get_node("%EmptyMessage").visible)
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


func test_inventory_selection_drives_existing_equip_and_hat_actions() -> void:
	var region := PLAYER.instantiate()
	add_child_autofree(region)
	InventoryManager.add_item("fishing_rod")
	InventoryManager.add_item("fisher_hat")
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	assert_true(ui.open_inventory())
	ui._select_item("fishing_rod")
	assert_eq(ui.get_node("%ItemName").text, ItemDatabase.get_display_name("fishing_rod"))
	assert_not_null(ui.get_node("%ItemPreview").texture)
	ui.get_node("%ActionButton").pressed.emit()
	assert_true(region.get_node("player").fishing_rod.is_equipped())
	assert_eq(ui.get_node("%ActionButton").text, "Unequip")
	ui._select_item("fisher_hat")
	ui.get_node("%ActionButton").pressed.emit()
	assert_eq(InventoryManager.equipped_costume, "fisher_hat")
	assert_eq(ui.get_node("%ActionButton").text, "Remove Hat")
	ui.close_inventory()
	assert_false(get_tree().paused)


func test_inventory_placeholder_slots_are_not_capacity_and_bait_stays_unusable() -> void:
	InventoryManager.add_item("energy_bait", 3)
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	ui._select_item("energy_bait")
	assert_true(ui.get_node("%ActionButton").disabled)
	assert_string_contains(ui.get_node("%ItemStatus").text, "No usable effect")
	assert_eq(InventoryManager.get_item_count("energy_bait"), 3)
	assert_eq(ui.get_node("%ItemCount").text, "Items: 1")
	assert_eq(ui.item_list_container.get_child_count(), 12)
	InventoryManager.remove_item("energy_bait", 3)
	assert_eq(ui._selected_item, "")
	assert_true(ui.get_node("%ActionButton").disabled)
	assert_null(ui.get_node("%ItemPreview").texture)


func test_inventory_responsive_grid_and_action_stay_reachable() -> void:
	InventoryManager.add_item("fishing_rod")
	var holder := Control.new()
	add_child_autofree(holder)
	var ui := INVENTORY.instantiate()
	holder.add_child(ui)
	assert_true(ui.open_inventory())
	for resolution in [Vector2(390, 844), Vector2(600, 900), Vector2(856, 428), Vector2(1280, 720)]:
		holder.size = resolution
		for i in 8:
			await get_tree().process_frame
		ui._update_layout()
		assert_true(
			Rect2(Vector2.ZERO, resolution).encloses(ui.get_node("%CloseButton").get_global_rect()),
			str(resolution)
		)
		assert_eq(ui.get_node("%Body").vertical, resolution.x < 700)
		assert_gt(ui.get_node("%BodyScroll").size.y, 40.0)
		assert_lte(
			ui.get_node("%BodyScroll").get_h_scroll_bar().max_value,
			ui.get_node("%BodyScroll").size.x + 1
		)
		assert_gte(ui.get_node("%ActionButton").size.y, 48.0)
		if resolution.x >= 700:
			assert_true(
				Rect2(Vector2.ZERO, resolution).encloses(
					ui.get_node("%ActionButton").get_global_rect()
				),
				"Action stays visible in landscape"
			)
		else:
			ui.get_node("%BodyScroll").scroll_vertical = int(
				ui.get_node("%BodyScroll").get_v_scroll_bar().max_value
			)
			for i in 3:
				await get_tree().process_frame
			assert_true(
				Rect2(Vector2.ZERO, resolution).encloses(
					ui.get_node("%ActionButton").get_global_rect()
				),
				"Action is reachable by scrolling in portrait"
			)
	ui.close_inventory()


func test_inventory_selection_does_not_mutate_items_or_points_and_has_no_twelve_item_cap() -> void:
	for i in 14:
		InventoryManager.add_item("inventory_layout_fixture_%d" % i)
	var before := InventoryManager.get_all_items()
	var points := FishingManager.get_points()
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	assert_eq(ui._slot_buttons.size(), 14)
	assert_eq(ui.item_list_container.get_child_count(), 14)
	ui._select_item("inventory_layout_fixture_4")
	ui.set_sort_mode("quantity")
	ui._on_filter_pressed("material")
	ui._on_filter_pressed("all")
	assert_eq(InventoryManager.get_all_items(), before)
	assert_eq(FishingManager.get_points(), points)


func test_inventory_keyboard_focus_survives_sorting_and_codex_handoff_releases_pause() -> void:
	InventoryManager.add_item("fishing_rod")
	InventoryManager.add_item("fish", 4)
	var ui := INVENTORY.instantiate()
	add_child_autofree(ui)
	assert_true(ui.open_inventory())
	ui._slot_buttons.fishing_rod.grab_focus()
	ui.set_sort_mode("quantity")
	assert_eq(get_viewport().gui_get_focus_owner(), ui._slot_buttons.fishing_rod)
	watch_signals(EventBus)
	ui.get_node("%CodexButton").pressed.emit()
	assert_signal_emitted(EventBus, "codex_open_requested")
	assert_false(ui.visible)
	assert_false(get_tree().paused)


func test_shop_selection_details_and_purchase_keep_existing_rules() -> void:
	var ui := SHOP.instantiate()
	add_child_autofree(ui)
	ui._on_catalog_ready("general_store", ShopManager.get_current_catalog())
	assert_eq(ui._item_buttons.size(), 2)
	assert_eq(ui.get_node("%ItemName").text, "Fishing Rod")
	assert_false(ui.get_node("%QuantityRow").visible)
	assert_true(ui.get_node("%FixedQuantity").visible)
	var points := FishingManager.get_points()
	ui._select_item("fisher_hat")
	assert_eq(FishingManager.get_points(), points)
	assert_eq(ui.get_node("%ItemName").text, "Fisher's Hat")
	assert_eq(ui.get_node("%Total").text, "Total: 50 points")
	ui.get_node("%BuyButton").pressed.emit()
	assert_eq(FishingManager.get_points(), points - 50)
	assert_eq(InventoryManager.get_item_count("fisher_hat"), 1)
	assert_true(ui.get_node("%BuyButton").disabled)
	assert_eq(ui.get_node("%Status").text, "Already owned.")
	assert_true(ShopManager.is_selling_enabled())
	ui._on_close_pressed()
	assert_false(get_tree().paused)


func test_shop_phone_navigation_and_small_landscape_bounds() -> void:
	var ui := SHOP.instantiate()
	add_child_autofree(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(390, 844)
	ui._on_catalog_ready("general_store", ShopManager.get_current_catalog())
	assert_true(ui.get_node("%Catalog").visible)
	assert_false(ui.get_node("%Paper").visible)
	ui._select_item("fishing_rod")
	assert_true(ui.get_node("%Paper").visible)
	assert_false(ui.get_node("%Catalog").visible)
	ui.get_node("%BackButton").pressed.emit()
	assert_true(ui.get_node("%Catalog").visible)
	for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844)]:
		ui.size = dimensions
		ui._select_item("fishing_rod")
		for frame in 12:
			await get_tree().process_frame
		assert_true(
			Rect2(Vector2.ZERO, dimensions).encloses(ui.get_node("%Panel").get_rect()),
			str(dimensions)
		)
		assert_true(
			(
				ui.get_node("%BuyButton").get_global_rect().end.y
				<= ui.get_node("%Panel").get_global_rect().end.y
			)
		)
	ui._on_close_pressed()


func test_shop_bulk_quantity_and_empty_catalog_are_safe() -> void:
	ShopManager._shop_definitions["general_store"].items_for_sale.append(
		{"item_id": "fish", "stock": 10, "price_override": 2}
	)
	ShopManager._remaining_stock["general_store"]["fish"] = 10
	var ui := SHOP.instantiate()
	add_child_autofree(ui)
	ui._on_catalog_ready("general_store", ShopManager.get_current_catalog())
	ui._select_item("fish")
	assert_true(ui.get_node("%QuantityRow").visible)
	ui.get_node("%Quantity").value = 3
	assert_eq(ui.get_node("%Total").text, "Total: 6 points")
	ui.get_node("%BuyButton").pressed.emit()
	assert_eq(InventoryManager.get_item_count("fish"), 3)
	assert_eq(FishingManager.get_points(), 94)
	assert_eq(ui.get_node("%Stock").text, "Stock: 7")
	ui._render_list([])
	assert_true(ui._selected.is_empty())
	assert_false(ui.get_node("%Purchase").visible)
	ui._on_close_pressed()


func test_sell_tab_sells_owned_quantity_without_awarding_aqpi_points() -> void:
	InventoryManager.add_item("tilapia", 3)
	InventoryManager.add_item("fishing_rod")
	InventoryManager.add_item("explorer_badge")
	InventoryManager.add_item("fisher_hat")
	var earned := PerformanceTracker.total_points_earned
	var ui := SHOP.instantiate()
	add_child_autofree(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(390, 844)
	ui._on_catalog_ready("general_store", ShopManager.get_current_catalog())
	ui.get_node("%SellTab").pressed.emit()
	assert_eq(ui._item_buttons.keys(), ["tilapia"])
	ui._item_buttons["tilapia"].pressed.emit()
	ui.get_node("%Quantity").value = 3
	assert_eq(ui.get_node("%BuyButton").text, "Sell ×3 · 12 points")
	ui.get_node("%BuyButton").pressed.emit()
	assert_eq(InventoryManager.get_item_count("tilapia"), 0)
	assert_eq(FishingManager.get_points(), 112)
	assert_eq(FishingManager.get_performance_points(), 100)
	assert_eq(FishingManager.get_total_points_earned(), 100)
	assert_eq(PerformanceTracker.total_points_earned, earned)
	assert_eq(ui.get_node("%PointsLabel").text, "Points: 112")
	assert_true(ui.get_node("%Catalog").visible)
	assert_true(ui._item_buttons.is_empty())
	var saved: Dictionary = JSON.parse_string(JSON.stringify(FishingManager._get_points_save_data()))
	FishingManager._apply_points_save_data(saved)
	assert_eq(FishingManager.get_points(), 112)
	assert_eq(FishingManager.get_performance_points(), 100)


func test_invalid_sales_leave_inventory_and_points_intact() -> void:
	InventoryManager.add_item("fish", 2)
	InventoryManager.add_item("fishing_rod")
	assert_false(ShopManager.sell_item("fish", 3))
	assert_false(ShopManager.sell_item("fish", 0))
	assert_false(ShopManager.sell_item("fishing_rod"))
	ShopManager.close_shop()
	assert_false(ShopManager.sell_item("fish"))
	assert_eq(InventoryManager.get_item_count("fish"), 2)
	assert_eq(InventoryManager.get_item_count("fishing_rod"), 1)
	assert_eq(FishingManager.get_points(), 100)
