extends GutTest

const INVENTORY_SCRIPT := preload("res://Autoload/InventoryManager.gd")


func test_all_authored_item_definitions_load_at_startup() -> void:
	var file := FileAccess.open("res://Data/JSON/Item/items.json", FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var definitions = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(definitions is Array)
	if not definitions is Array:
		return
	assert_gt(definitions.size(), 0)
	for definition in definitions:
		var item_id: String = definition["item_id"]
		assert_true(ItemDatabase.has_definition(item_id), "Missing item: " + item_id)
		assert_eq(ItemDatabase.get_item_definition(item_id), definition)


func test_equipment_and_costumes_use_the_existing_authored_metadata() -> void:
	assert_eq(ItemDatabase.get_display_name("fishing_rod"), "Fishing Rod")
	assert_eq(ItemDatabase.get_max_stack("fishing_rod"), 1)
	assert_false(ItemDatabase.is_sellable("fishing_rod"))
	assert_eq(ItemDatabase.get_category("fisher_hat"), "costume")
	assert_true(ItemDatabase.is_one_time_purchase("fisher_hat"))
	assert_eq(ItemDatabase.get_buy_price("fisher_hat"), 50)
	assert_eq(ItemDatabase.get_category("explorer_badge"), "quest_item")


func test_inventory_applies_loaded_stack_limits_without_touching_player_inventory() -> void:
	# Keep this inventory outside the tree so it cannot register a save section.
	var inventory = autofree(INVENTORY_SCRIPT.new())
	inventory.add_item("fishing_rod", 2)
	inventory.add_item("energy_bait", 25)
	assert_eq(inventory.get_item_count("fishing_rod"), 1)
	assert_eq(inventory.get_item_count("energy_bait"), 20)


func test_undefined_items_keep_the_existing_fallback_behavior() -> void:
	const UNKNOWN_ID := "gut_undefined_item"
	assert_false(ItemDatabase.has_definition(UNKNOWN_ID))
	assert_eq(ItemDatabase.get_display_name(UNKNOWN_ID), UNKNOWN_ID)
	assert_eq(ItemDatabase.get_category(UNKNOWN_ID), "item")
	assert_eq(ItemDatabase.get_max_stack(UNKNOWN_ID), 999)
	assert_eq(ItemDatabase.get_buy_price(UNKNOWN_ID), 0)
