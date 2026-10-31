class_name InventoryUI
extends Control
## Presentation and input only; managers own item/equipment state.

const CARD := preload("res://Scripts/Systems/Inventory/ItemCard.gd")
const CATEGORIES := ["all", "item", "quest_item", "consumable", "costume", "material"]
const SORT_MODES := ["name", "category", "quantity"]

var _current_filter := "all"
var _current_sort := "name"
var _owns_pause := false
var _previous_focus: WeakRef

@onready var item_list_container: VBoxContainer = %ItemListContainer
@onready var filter_container: HBoxContainer = %FilterContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	EventBus.inventory_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_on_equipment_changed)
	EventBus.load_completed.connect(_on_loaded)
	_build_filter_buttons()
	%CodexButton.pressed.connect(_on_codex_pressed)
	%CloseButton.pressed.connect(close_inventory)
	for mode in SORT_MODES:
		%SortList.add_item("Sort: " + mode.capitalize())
	%SortList.item_selected.connect(func(index: int): set_sort_mode(SORT_MODES[index]))
	_refresh()


func open_inventory() -> bool:
	if visible:
		return true
	if (
		get_tree().paused
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or DialogueManager.is_active
		or FishingManager.is_fishing()
	):
		return false
	for overlay in get_tree().get_nodes_in_group("gameplay_overlay"):
		if overlay != self and overlay is Control and overlay.is_visible_in_tree():
			return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_owns_pause = true
	GameManager.set_paused(true)
	show()
	_refresh()
	%CloseButton.grab_focus()
	return true


func close_inventory() -> void:
	hide()
	_release_pause()
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		GameManager.set_paused(false)


func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
	if (
		visible
		and (
			event.is_action_pressed("ui_cancel")
			or (
				event is InputEventKey
				and event.pressed
				and not event.echo
				and event.keycode == KEY_I
			)
		)
	):
		close_inventory()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _on_codex_pressed() -> void:
	close_inventory()
	EventBus.codex_open_requested.emit()


func _build_filter_buttons() -> void:
	var group := ButtonGroup.new()
	for category in CATEGORIES:
		var button := Button.new()
		button.text = {"all": "All", "item": "Equipment", "quest_item": "Quest Items"}.get(
			category, category.capitalize()
		)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = category == _current_filter
		button.pressed.connect(_on_filter_pressed.bind(category))
		filter_container.add_child(button)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = (
			(
				button
				. get_theme_font("font")
				. get_string_size(
					button.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					button.get_theme_font_size("font_size")
				)
				. x
			)
			+ 32
		)


func _on_filter_pressed(category: String) -> void:
	_current_filter = category
	_refresh()


func set_sort_mode(mode: String) -> void:
	if SORT_MODES.has(mode):
		_current_sort = mode
		%SortList.select(SORT_MODES.find(mode))
		_refresh()


func _on_equipment_changed(_item_id: String) -> void:
	_refresh()


func _on_loaded(_slot: int) -> void:
	_refresh()


func _refresh() -> void:
	if item_list_container == null:
		return
	for child in item_list_container.get_children():
		item_list_container.remove_child(child)
		child.queue_free()
	var owned := InventoryManager.get_all_items()
	var ids: Array = owned.keys()
	if _current_filter != "all":
		ids = ids.filter(
			func(id: String) -> bool: return ItemDatabase.get_category(id) == _current_filter
		)
	ids = _sort_ids(ids, owned)
	if ids.is_empty():
		CARD.add_text(
			item_list_container,
			"Your inventory is empty." if owned.is_empty() else "No items in this category."
		)
	for item_id in ids:
		item_list_container.add_child(_build_row(item_id, owned[item_id]))


func _sort_ids(ids: Array, owned: Dictionary) -> Array:
	ids.sort_custom(
		func(a, b):
			if _current_sort == "quantity" and owned[a] != owned[b]:
				return owned[a] > owned[b]
			if (
				_current_sort == "category"
				and ItemDatabase.get_category(a) != ItemDatabase.get_category(b)
			):
				return ItemDatabase.get_category(a) < ItemDatabase.get_category(b)
			return ItemDatabase.get_display_name(a) < ItemDatabase.get_display_name(b)
	)
	return ids


func _rod() -> FishingRodComponent:
	for player in get_tree().get_nodes_in_group("player"):
		if player is Player and player.is_multiplayer_authority():
			return player.fishing_rod
	return null


func _build_row(item_id: String, count: int) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"AquaInset"
	var card := CARD.build(item_id, count)
	panel.add_child(card)
	if item_id == "fishing_rod":
		var rod := _rod()
		CARD.add_text(card, "Equipped" if rod != null and rod.is_equipped() else "Not equipped")
		var button := Button.new()
		button.text = "Unequip" if rod != null and rod.is_equipped() else "Equip"
		button.disabled = rod == null
		button.pressed.connect(
			func():
				var current := _rod()
				if current != null:
					current.toggle()
		)
		card.add_child(button)
	elif item_id == "fisher_hat":
		var button := Button.new()
		button.text = "Remove Hat" if InventoryManager.equipped_costume == item_id else "Wear Hat"
		button.pressed.connect(func(): InventoryManager.toggle_costume(item_id))
		card.add_child(button)
		CARD.add_text(card, "Cosmetic only. No gameplay bonus.")
	elif ItemDatabase.get_category(item_id) == "consumable":
		CARD.add_text(card, "No usable effect configured. This item is not consumed.")
	return panel
