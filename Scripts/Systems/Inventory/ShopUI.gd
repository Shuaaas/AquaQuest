class_name ShopUI
extends Control
## Catalog presentation; all availability and purchase rules live in ShopManager.

var _points_label: Label
var _owns_pause := false
var _previous_focus: WeakRef
var _quantities: Dictionary = {}
var _controls: Dictionary = {}
var _catalog: Array = []
var _selected := ""
var _reading := false
var _item_buttons: Dictionary = {}

@onready var buy_list_container: VBoxContainer = %BuyListContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Copy source data only; duplicating a live font also copies its glyph cache.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	%BuyButton.pressed.connect(_buy_selected)
	%Less.pressed.connect(func(): %Quantity.value -= 1)
	%More.pressed.connect(func(): %Quantity.value += 1)
	%Quantity.value_changed.connect(_on_quantity_changed)
	%BackButton.pressed.connect(_back_to_list)
	resized.connect(_layout)
	%Panel.minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()
	_points_label = %PointsLabel
	close_button.pressed.connect(_on_close_pressed)
	EventBus.shop_catalog_ready.connect(_on_catalog_ready)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.item_purchased.connect(_on_purchase)
	EventBus.fishing_points_changed.connect(_on_points_changed)
	EventBus.inventory_changed.connect(_update_availability)
	EventBus.load_completed.connect(_on_loaded)


func _on_catalog_ready(_shop_id: String, catalog: Array) -> void:
	if (
		SaveManager.is_loading
		or SceneLoader.is_loading()
		or DialogueManager.is_active
		or FishingManager.is_fishing()
	):
		ShopManager.close_shop()
		return
	for overlay in get_tree().get_nodes_in_group("gameplay_overlay"):
		if overlay != self and overlay is Control and overlay.is_visible_in_tree():
			ShopManager.close_shop()
			return
	if get_tree().paused and not _owns_pause:
		ShopManager.close_shop()
		return
	if not visible:
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null else null
		_owns_pause = true
		GameManager.set_paused(true)
		_quantities.clear()
		_selected = ""
		_reading = false
	show()
	_refresh_points()
	_render_buy_list(catalog)
	close_button.grab_focus()


func _refresh_points() -> void:
	_points_label.text = "Points: %d" % FishingManager.get_points()


func _render_buy_list(catalog: Array) -> void:
	_catalog = catalog.duplicate(true)
	_item_buttons.clear()
	for child in buy_list_container.get_children():
		buy_list_container.remove_child(child)
		child.queue_free()
	var ids: Array = catalog.map(func(entry): return entry["item_id"])
	if not _selected in ids:
		_selected = str(ids[0]) if not ids.is_empty() else ""
	for entry in catalog:
		var item_id: String = entry["item_id"]
		var button := Button.new()
		button.text = (
			"%s\n%d points · Stock: %s"
			% [entry.display_name, entry.price, _stock_text(entry.stock)]
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 88
		button.toggle_mode = true
		button.button_pressed = item_id == _selected
		button.icon = _icon(item_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 48)
		button.pressed.connect(_select_item.bind(item_id))
		buy_list_container.add_child(button)
		_item_buttons[item_id] = button
	if catalog.is_empty():
		var label := Label.new()
		label.text = "No items available in this shop."
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy_list_container.add_child(label)
	_show_selected()


func _stock_text(stock: int) -> String:
	return "Unlimited" if stock < 0 else str(stock)


func _icon(item_id: String) -> Texture2D:
	var path := ItemDatabase.get_icon_path(item_id)
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _select_item(item_id: String) -> void:
	_selected = item_id
	_reading = true
	for id in _item_buttons:
		_item_buttons[id].set_pressed_no_signal(id == item_id)
	_show_selected()
	%DetailScroll.scroll_vertical = 0
	if size.x < 700:
		%BackButton.grab_focus()


func _show_selected() -> void:
	_controls.clear()
	%Details.visible = not _selected.is_empty()
	%Purchase.visible = not _selected.is_empty()
	if _selected.is_empty():
		_reading = false
		_layout()
		return
	var entry: Dictionary = {}
	for item in _catalog:
		if item.item_id == _selected:
			entry = item
	%ItemName.text = entry.display_name
	%Rarity.text = (
		"%s · %s"
		% [
			ItemDatabase.get_rarity_name(_selected),
			"★".repeat(ItemDatabase.get_rarity_stars(_selected))
		]
	)
	%Description.text = entry.description
	%ItemIcon.texture = _icon(_selected)
	%UnitPrice.text = "Unit price: %d points" % int(entry.price)
	%Stock.text = "Stock: " + _stock_text(int(entry.stock))
	var limit := (
		1
		if ItemDatabase.is_one_time_purchase(_selected)
		else mini(999, ItemDatabase.get_max_stack(_selected))
	)
	%Quantity.set_value_no_signal(1)
	%Quantity.max_value = limit
	%Quantity.set_value_no_signal(clampi(int(_quantities.get(_selected, 1)), 1, limit))
	%QuantityRow.visible = limit > 1
	%FixedQuantity.visible = limit == 1
	_controls[_selected] = {
		"quantity": %Quantity, "status": %Status, "buy": %BuyButton, "price": entry.price
	}
	_update_availability()
	_layout()
	_layout.call_deferred()


func _on_quantity_changed(value: float) -> void:
	if not _selected.is_empty():
		_quantities[_selected] = int(value)
		_update_availability()


func _update_availability() -> void:
	if not visible or _selected.is_empty() or not _controls.has(_selected):
		return
	var controls: Dictionary = _controls[_selected]
	var quantity := int(controls.quantity.value)
	var reason := ShopManager.purchase_error(_selected, quantity)
	controls.status.text = reason if not reason.is_empty() else "Ready to buy."
	controls.buy.disabled = not reason.is_empty()
	var total := int(controls.price) * quantity
	controls.buy.text = "Buy ×%d · %d points" % [quantity, total]
	%Total.text = "Total: %d points" % total
	%Owned.text = "Owned: %d" % InventoryManager.get_item_count(_selected)
	%Less.disabled = quantity <= 1
	%More.disabled = quantity >= %Quantity.max_value


func _buy_selected() -> void:
	if not _selected.is_empty():
		ShopManager.buy_item(_selected, int(%Quantity.value))


func _back_to_list() -> void:
	_reading = false
	_layout()
	if _item_buttons.has(_selected):
		_item_buttons[_selected].grab_focus()


func _layout() -> void:
	if not is_node_ready():
		return
	var compact := size.x < 700
	var padding := 12.0 if compact or size.y < 450 else 32.0
	%Panel.size = (size - Vector2.ONE * padding * 2).min(Vector2(1100, 800))
	%Panel.position = (size - %Panel.size) / 2
	%Catalog.custom_minimum_size.x = 0 if compact else 230
	%Catalog.visible = not compact or not _reading
	%Paper.visible = not _selected.is_empty() and (not compact or _reading)
	%BackButton.visible = compact
	%Subtitle.visible = size.y > 450
	%ItemIcon.custom_minimum_size = Vector2.ONE * (40 if size.y < 450 else 56)
	%IconFrame.custom_minimum_size = Vector2.ONE * (64 if size.y < 450 else 80)


func _on_purchase(_item_id: String, _price: int) -> void:
	if visible:
		_render_buy_list(ShopManager.get_current_catalog())


func _on_points_changed(_new_total: int, _delta: int) -> void:
	_refresh_points()
	_update_availability()


func _on_loaded(_slot: int) -> void:
	if visible:
		_render_buy_list(ShopManager.get_current_catalog())


func _on_close_pressed() -> void:
	ShopManager.close_shop()


func _on_shop_closed() -> void:
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
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
