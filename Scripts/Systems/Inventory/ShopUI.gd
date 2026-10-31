class_name ShopUI
extends Control
## Catalog presentation; all availability and purchase rules live in ShopManager.

const CARD := preload("res://Scripts/Systems/Inventory/ItemCard.gd")
var _points_label: Label
var _owns_pause := false
var _previous_focus: WeakRef
var _quantities: Dictionary = {}
var _controls: Dictionary = {}

@onready var buy_list_container: VBoxContainer = %BuyListContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
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
	show()
	_refresh_points()
	_render_buy_list(catalog)
	close_button.grab_focus()


func _refresh_points() -> void:
	_points_label.text = "Points: %d" % FishingManager.get_points()


func _render_buy_list(catalog: Array) -> void:
	_controls.clear()
	for child in buy_list_container.get_children():
		buy_list_container.remove_child(child)
		child.queue_free()
	if catalog.is_empty():
		CARD.add_text(buy_list_container, "No items available in this shop.")
	for entry in catalog:
		var item_id: String = entry["item_id"]
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"AquaInset"
		var card := CARD.build(item_id, InventoryManager.get_item_count(item_id))
		panel.add_child(card)
		var stock: int = entry.get("stock", -1)
		CARD.add_text(
			card,
			(
				"Unit price: %d points | Stock: %s"
				% [entry["price"], "Unlimited" if stock < 0 else str(stock)]
			)
		)
		var quantity := SpinBox.new()
		quantity.prefix = "Quantity: "
		quantity.min_value = 1
		quantity.max_value = (
			1
			if ItemDatabase.is_one_time_purchase(item_id)
			else mini(999, ItemDatabase.get_max_stack(item_id))
		)
		quantity.step = 1
		quantity.custom_minimum_size.y = 48
		quantity.value = _quantities.get(item_id, 1)
		var quantity_row := HBoxContainer.new()
		card.add_child(quantity_row)
		var less := Button.new()
		less.text = "-"
		less.custom_minimum_size = Vector2(48, 48)
		less.pressed.connect(func(): quantity.value -= 1)
		quantity_row.add_child(less)
		quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quantity_row.add_child(quantity)
		var more := Button.new()
		more.text = "+"
		more.custom_minimum_size = Vector2(48, 48)
		more.pressed.connect(func(): quantity.value += 1)
		quantity_row.add_child(more)
		less.disabled = quantity.max_value == 1
		more.disabled = quantity.max_value == 1
		var status := CARD.add_text(card, "")
		var buy := Button.new()
		buy.pressed.connect(func(): ShopManager.buy_item(item_id, int(quantity.value)))
		card.add_child(buy)
		_controls[item_id] = {
			"quantity": quantity, "status": status, "buy": buy, "price": entry["price"]
		}
		quantity.value_changed.connect(
			func(value: float):
				_quantities[item_id] = int(value)
				_update_availability()
		)
		buy_list_container.add_child(panel)
	CARD.add_text(buy_list_container, "Selling is not available.")
	_update_availability()


func _update_availability() -> void:
	if not visible:
		return
	for item_id in _controls:
		var controls: Dictionary = _controls[item_id]
		var quantity := int(controls.quantity.value)
		var reason := ShopManager.purchase_error(item_id, quantity)
		controls.status.text = reason if not reason.is_empty() else "Ready to buy."
		controls.buy.disabled = not reason.is_empty()
		controls.buy.text = "Buy x%d - %d points" % [quantity, int(controls.price) * quantity]


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
