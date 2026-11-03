class_name InventoryUI
extends Control
## Presentation and input only; managers own item/equipment state.

const CATEGORIES := ["all", "item", "quest_item", "consumable", "costume", "material"]
const SORT_MODES := ["name", "category", "quantity"]

var _selected_item := ""
var _slot_buttons: Dictionary = {}
var _current_filter := "all"
var _current_sort := "name"
var _owns_pause := false
var _previous_focus: WeakRef

@onready var item_list_container: GridContainer = %ItemListContainer
@onready var filter_container: HBoxContainer = %FilterContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	theme.default_font = preload("res://Scripts/UI/PixelUIStyle.gd").shared_theme().default_font
	resized.connect(_update_layout)
	%BodyScroll.resized.connect(_update_layout)
	%GridScroll.resized.connect(_size_slots)
	%ActionButton.pressed.connect(_on_action_pressed)
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
		button.add_theme_stylebox_override(
			"pressed", get_theme_stylebox("pressed", "InventorySelected")
		)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = category == _current_filter
		button.pressed.connect(_on_filter_pressed.bind(category))
		filter_container.add_child(button)
		button.custom_minimum_size.y = 48
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
	var focus := get_viewport().gui_get_focus_owner()
	var restore_item_focus := focus != null and item_list_container.is_ancestor_of(focus)
	var focused_item: String = str(focus.get_meta("item_id", "")) if restore_item_focus else ""
	_slot_buttons.clear()
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
	if _selected_item not in ids:
		_selected_item = str(ids[0]) if not ids.is_empty() else ""
	%ItemCount.text = "Items: %d" % owned.size()
	%EmptyMessage.visible = ids.is_empty()
	%EmptyMessage.text = (
		"Your inventory is empty." if owned.is_empty() else "No items in this category."
	)
	for item_id in ids:
		var button := _build_slot(item_id, int(owned[item_id]))
		_slot_buttons[item_id] = button
		item_list_container.add_child(button)
	# Twelve visible placeholders describe the grid, not an inventory capacity.
	for i in maxi(0, 12 - ids.size()):
		var slot := Button.new()
		slot.disabled = true
		slot.custom_minimum_size = Vector2(72, 72)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.tooltip_text = "Empty slot"
		item_list_container.add_child(slot)
	_show_selection()
	_update_layout()
	if restore_item_focus and is_visible_in_tree() and _slot_buttons.has(_selected_item):
		(
			_slot_buttons[focused_item if _slot_buttons.has(focused_item) else _selected_item]
			. grab_focus()
		)


func _build_slot(item_id: String, count: int) -> Button:
	var button := Button.new()
	button.set_meta("item_id", item_id)
	button.add_theme_stylebox_override(
		"pressed", get_theme_stylebox("pressed", "InventorySelected")
	)
	button.toggle_mode = true
	button.button_pressed = item_id == _selected_item
	button.custom_minimum_size = Vector2(72, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.icon = _item_icon(item_id)
	button.tooltip_text = "%s ×%d" % [ItemDatabase.get_display_name(item_id), count]
	button.accessibility_name = button.tooltip_text
	button.pressed.connect(_select_item.bind(item_id))
	if button.icon == null:
		button.text = ItemDatabase.get_display_name(item_id)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if count > 1:
		var quantity := Label.new()
		quantity.text = "×%d" % count
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quantity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quantity.offset_right = -10
		quantity.offset_bottom = -8
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		quantity.add_theme_color_override("font_shadow_color", Color("21160f"))
		quantity.add_theme_constant_override("shadow_offset_x", 1)
		quantity.add_theme_constant_override("shadow_offset_y", 1)
		button.add_child(quantity)
	return button


func _item_icon(item_id: String) -> Texture2D:
	var path := ItemDatabase.get_icon_path(item_id)
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _select_item(item_id: String) -> void:
	if not InventoryManager.has_item(item_id):
		_refresh()
		return
	_selected_item = item_id
	for id in _slot_buttons:
		_slot_buttons[id].set_pressed_no_signal(id == item_id)
	_show_selection()


func _show_selection() -> void:
	var item_id := _selected_item
	%ItemPreview.texture = _item_icon(item_id) if not item_id.is_empty() else null
	%ItemName.text = (
		ItemDatabase.get_display_name(item_id) if not item_id.is_empty() else "Select an item"
	)
	%CompactItemName.text = %ItemName.text
	%ItemCategory.text = "Choose an item to see its details."
	%ItemRarity.text = ""
	%ItemDescription.text = ""
	%ItemQuantity.text = ""
	%ItemStatus.text = ""
	%ActionButton.text = "Select an item"
	%ActionButton.disabled = true
	if item_id.is_empty():
		return
	var category := ItemDatabase.get_category(item_id)
	%ItemCategory.text = (
		"%s · %s"
		% [
			{"item": "Equipment", "quest_item": "Quest item"}.get(category, category.capitalize()),
			ItemDatabase.get_rarity_name(item_id)
		]
	)
	%ItemRarity.text = "★".repeat(ItemDatabase.get_rarity_stars(item_id))
	%ItemRarity.add_theme_color_override("font_color", Color("c6a66a"))
	%ItemDescription.text = ItemDatabase.get_description(item_id)
	%ItemQuantity.text = (
		"Quantity: %d · Stack limit: %d"
		% [InventoryManager.get_item_count(item_id), ItemDatabase.get_max_stack(item_id)]
	)
	%ActionButton.text = "No action available"
	if item_id == "fishing_rod":
		var rod := _rod()
		%ActionButton.text = "Unequip" if rod != null and rod.is_equipped() else "Equip"
		%ActionButton.disabled = rod == null
		%ItemStatus.text = "Equipped" if rod != null and rod.is_equipped() else "Not equipped"
		if rod == null:
			%ItemStatus.text = "Equipment is available while playing in a region."
	elif item_id == "fisher_hat":
		%ActionButton.text = (
			"Remove Hat" if InventoryManager.equipped_costume == item_id else "Wear Hat"
		)
		%ActionButton.disabled = false
		%ItemStatus.text = "Cosmetic only. No gameplay bonus."
	elif category == "consumable":
		%ItemStatus.text = "No usable effect configured. This item is not consumed."


func _on_action_pressed() -> void:
	if not InventoryManager.has_item(_selected_item):
		_refresh()
		return
	if _selected_item == "fishing_rod":
		var rod := _rod()
		if rod != null:
			rod.toggle()
	elif _selected_item == "fisher_hat":
		InventoryManager.toggle_costume(_selected_item)
	_show_selection()


func _update_layout() -> void:
	if not is_node_ready() or size.x <= 0:
		return
	var stacked := size.x < 700
	%Body.vertical = stacked
	var short_landscape := not stacked and size.y < 500
	%CompactItemName.visible = short_landscape
	%ItemName.visible = not short_landscape
	%ItemPreview.custom_minimum_size.y = 48 if short_landscape else 112
	var height := 300.0 if stacked else maxf(120.0, %BodyScroll.size.y)
	%GridPanel.custom_minimum_size.y = height
	%DetailsPanel.custom_minimum_size.y = maxf(340.0, height) if stacked else height
	_size_slots()


func _size_slots() -> void:
	if not is_node_ready():
		return
	var cell := maxf(72.0, floorf((%GridScroll.size.x - 24.0) / 3.0))
	for child in item_list_container.get_children():
		child.custom_minimum_size = Vector2(72, cell)


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
