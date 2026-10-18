extends Control
class_name ShopUI
## ShopUI
##
## Displays a merchant's catalog and the player's current POINTS balance.
## Prices are in points - the player's existing score from answering
## questions - not a separate currency (Phase 13 fix).
## Knows nothing about purchase RULES (ShopManager's job) or item DATA
## (ItemDatabase's job) - it only reacts to EventBus signals and calls
## ShopManager.buy_item()/close_shop().
##
## PAUSE-SAFE BY CONSTRUCTION, same reasoning as FishingUI/ExamUI: opening
## a shop pauses gameplay (consistent with fishing/exam questions already
## doing this), so this scene sets its own Process Mode to "Always" in
## code rather than relying on a manual Inspector step.
##
## SETUP: attach to a Control root. Requires BuyListContainer and
## SellListContainer (VBoxContainer each), both marked "Access as Unique
## Name", plus a CloseButton (Button). A Label named "PointsLabel" (unique
## name) is OPTIONAL - if you don't add one, this script creates its own at
## the top of the panel, so the points display can't be forgotten.
##
## The Sell panel only shows a notice: selling is disabled (see
## ShopManager.is_selling_enabled() for the reason).

@onready var buy_list_container: VBoxContainer = %BuyListContainer
@onready var close_button: Button = %CloseButton

var _points_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	close_button.pressed.connect(_on_close_pressed)

	_points_label = get_node_or_null("%PointsLabel")
	if _points_label == null:
		_points_label = Label.new()
		# CloseButton's parent is the panel's main VBoxContainer in the
		# documented scene layout - put the balance at the very top of it.
		var panel_root := close_button.get_parent()
		panel_root.add_child(_points_label)
		panel_root.move_child(_points_label, 0)

	EventBus.shop_catalog_ready.connect(_on_catalog_ready)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.item_purchased.connect(_on_purchase)
	# Any balance change (a purchase, or a quest/fishing award while the
	# shop is open) refreshes the displayed points immediately.
	EventBus.fishing_points_changed.connect(_on_points_changed)


func _on_catalog_ready(_shop_id: String, catalog: Array) -> void:
	visible = true
	GameManager.set_paused(true)
	_refresh_points()
	_render_buy_list(catalog)
	#_render_sell_panel()


func _refresh_points() -> void:
	_points_label.text = "Points: %d" % FishingManager.get_points()


func _render_buy_list(catalog: Array) -> void:
	for child in buy_list_container.get_children():
		child.queue_free()

	for entry in catalog:
		var item_id: String = entry.get("item_id", "")
		var price: int = entry.get("price", 0)
		var stock: int = entry.get("stock", -1)
		var already_purchased: bool = entry.get("already_purchased", false)

		var row := HBoxContainer.new()

		var label := Label.new()
		var status_text := ""
		if already_purchased:
			status_text = " (owned)"
		elif stock == 0:
			status_text = " (sold out)"
		elif stock > 0:
			status_text = " (%d left)" % stock
		label.text = "%s - %d points%s" % [entry.get("display_name", item_id), price, status_text]
		row.add_child(label)

		var buy_button := Button.new()
		buy_button.text = "Buy"
		buy_button.disabled = already_purchased or stock == 0
		buy_button.pressed.connect(func(): ShopManager.buy_item(item_id))
		row.add_child(buy_button)

		buy_list_container.add_child(row)

#
#func _render_sell_panel() -> void:
	#for child in sell_list_container.get_children():
		#child.queue_free()
#
	#if not ShopManager.is_selling_enabled():
		#var notice := Label.new()
		#notice.text = "Selling isn't available."
		#sell_list_container.add_child(notice)


func _on_purchase(_item_id: String, _price: int) -> void:
	if visible:
		_render_buy_list(ShopManager.get_current_catalog())


func _on_points_changed(_new_total: int, _delta: int) -> void:
	_refresh_points()


func _on_close_pressed() -> void:
	ShopManager.close_shop()


func _on_shop_closed() -> void:
	visible = false
	GameManager.set_paused(false)
