extends GutTest

const REWARD := preload("res://Scene/UI/ItemRewardToast.tscn")

var ui: Control

var generic: Control

var inventory_before: Dictionary

var definitions_before: Dictionary

var quests_before: Dictionary

var game_state: int


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	inventory_before = InventoryManager._get_save_data().duplicate(true)

	definitions_before = ItemDatabase._item_definitions.duplicate(true)

	quests_before = QuestManager._get_save_data().duplicate(true)

	game_state = GameManager.current_state

	QuestManager._apply_save_data({})

	InventoryManager._apply_save_data({})

	generic = Control.new()

	generic.name = "GenericToast"

	add_child(generic)

	generic.hide()

	ui = REWARD.instantiate()

	ui.generic_toast_path = NodePath("../GenericToast")

	add_child(ui)


func after_each() -> void:
	ui.free()

	generic.free()

	GameManager.set_paused(false)

	GameManager.current_state = game_state

	InventoryManager._apply_save_data(inventory_before)

	ItemDatabase._item_definitions = definitions_before

	QuestManager._apply_save_data(quests_before)

	await get_tree().process_frame


func test_four_tiers_default_and_invalid_metadata_are_safe() -> void:
	assert_eq(ItemDatabase.get_rarity("fishing_rod"), "common")

	for index in range(4):
		ItemDatabase._item_definitions.fishing_rod.rarity = ["common", "Advanced", "rare", "epic"][index]

		assert_eq(ItemDatabase.get_rarity_stars("fishing_rod"), index + 1)

	ItemDatabase._item_definitions.fishing_rod.rarity = "legendary"

	assert_eq(ItemDatabase.get_rarity_stars("fishing_rod"), 1)

	ItemDatabase._item_definitions.fishing_rod.rarity = 4

	assert_eq(ItemDatabase.get_rarity_stars("fishing_rod"), 1)

	assert_eq(ItemDatabase.get_rarity_stars("unknown_item"), 1)


func test_real_item_grant_shows_actual_quantity_name_description_and_icon() -> void:
	InventoryManager.add_item("energy_bait", 25)

	assert_true(ui.frame.visible)

	assert_eq(ui.quantity.text, "×20")

	assert_eq(ui.item_name.text, "Energy Bait")

	assert_eq(ui.description.text, ItemDatabase.get_description("energy_bait"))

	assert_not_null(ui.icon.texture)

	assert_eq(ui.frame.stars, 1)

	assert_false(get_tree().paused)


func test_multiple_grants_queue_and_pending_identical_items_merge() -> void:
	InventoryManager.add_item("fishing_rod")

	InventoryManager.add_item("fish", 2)

	InventoryManager.add_item("fish", 3)

	assert_eq(ui.item_name.text, "Fishing Rod")

	assert_eq(ui._pending.size(), 1)

	ui.dismiss_current()

	assert_eq(ui.item_name.text, "Fish")

	assert_eq(ui.quantity.text, "×5")

	ui.dismiss_current()

	assert_false(ui.frame.visible)


func test_generic_messages_and_pause_hide_card_without_losing_current_item() -> void:
	generic.show()

	InventoryManager.add_item("fishing_rod")

	assert_false(ui.frame.visible)

	assert_eq(ui._pending.size(), 1)

	generic.hide()

	ui._pump()

	assert_true(ui.frame.visible)

	GameManager.set_paused(true)

	ui._pump()

	assert_false(ui.frame.visible)

	assert_true(ui.timer.paused)

	assert_eq(ui._current.item_id, "fishing_rod")

	GameManager.set_paused(false)

	ui._pump()

	assert_true(ui.frame.visible)

	assert_false(ui.timer.paused)


func test_full_stack_and_save_restore_do_not_create_false_acquisitions() -> void:
	InventoryManager.add_item("fishing_rod")

	ui.dismiss_current()

	InventoryManager.add_item("fishing_rod", 10)

	assert_true(ui._current.is_empty())

	InventoryManager._apply_save_data({"items": {"fisher_hat": 1}})

	assert_true(ui._current.is_empty())

	assert_true(ui._pending.is_empty())


func test_successful_load_discards_previous_session_notices() -> void:
	InventoryManager.add_item("fishing_rod")

	InventoryManager.add_item("fish")

	EventBus.load_requested.emit(0)

	assert_eq(ui._current.item_id, "fishing_rod")

	assert_eq(ui._pending.size(), 1)

	EventBus.load_completed.emit(0)

	assert_true(ui._current.is_empty())

	assert_true(ui._pending.is_empty())

	assert_false(ui.frame.visible)


func test_unknown_item_has_readable_fallback_and_no_missing_resource_error() -> void:
	InventoryManager.add_item("gut_unknown_reward")

	assert_eq(ui.item_name.text, "gut_unknown_reward")

	assert_eq(ui.description.text, "Added to your inventory.")

	assert_true(ui.get_node("%MissingIcon").visible)


func test_expired_card_advances_queue_without_hiding_next_item() -> void:
	ui.display_duration = 0.05

	InventoryManager.add_item("fishing_rod")

	ui.display_duration = 2.0

	InventoryManager.add_item("fish")

	await get_tree().create_timer(0.12).timeout

	assert_eq(ui.item_name.text, "Fish")

	assert_true(ui.frame.visible)


func test_new_card_shows_only_filled_stars_and_keeps_description_and_dismiss_visible() -> void:
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844)]:
		ui.size = dimensions
		ui._on_item_added("fish", 1)
		for frame in 12:
			await get_tree().process_frame
		assert_true(Rect2(Vector2.ZERO, dimensions).encloses(ui.frame.get_rect()))
		assert_eq(ui.rarity.text, "★ Common")
		assert_eq(ui.quantity.text, "×1")
		var scroll: ScrollContainer = ui.get_node("%TextScroll")
		assert_lte(ui.description.get_global_rect().end.y, scroll.get_global_rect().end.y + 1)
		assert_gte(ui.get_node("%DismissButton").size.y, 48.0)
		ui.dismiss_current()
	for index in 4:
		ItemDatabase._item_definitions.fishing_rod.rarity = ["common", "advanced", "rare", "epic"][index]
		ui._on_item_added("fishing_rod", 1)
		assert_eq(ui.rarity.text.count("★"), index + 1)
		assert_false("☆" in ui.rarity.text)
		ui.dismiss_current()
