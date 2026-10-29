extends Control
class_name InventoryUI
## InventoryUI
##
## Displays the player's owned items with category Filtering and Sorting
## (both explicitly requested in the brief). Knows nothing about item
## DATA beyond what it reads from ItemDatabase, and nothing about item
## COUNTS beyond what it reads from InventoryManager - it only renders
## and reacts to EventBus.inventory_changed.
##
## SETUP: attach to a Control root. Requires ItemListContainer
## (a VBoxContainer or GridContainer) and FilterContainer (a
## HBoxContainer the filter buttons get added to), both marked
## "Access as Unique Name". A ToggleButton to open/close this from a HUD
## is up to you - this script has no toggle() method of its own; flip the
## node's `visible` property from wherever your HUD handles input.

const CATEGORIES := ["all", "fishing rod", "costume"]
const SORT_MODES := ["name", "category", "quantity"]

@onready var item_list_container: VBoxContainer = %ItemListContainer
@onready var filter_container: HBoxContainer = %FilterContainer

var _current_filter: String = "all"
var _current_sort: String = "name"


func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh)
	_build_filter_buttons()
	%CodexButton.pressed.connect(_on_codex_pressed)
	_refresh()


func _on_codex_pressed() -> void:
	EventBus.codex_open_requested.emit()


func _build_filter_buttons() -> void:
	for category in CATEGORIES:
		var button := Button.new()
		button.text = category.capitalize()
		button.pressed.connect(_on_filter_pressed.bind(category))
		filter_container.add_child(button)


func _on_filter_pressed(category: String) -> void:
	_current_filter = category
	_refresh()


## Call from a sort dropdown/button elsewhere in your HUD if you add one -
## cycles through SORT_MODES, or call with an explicit mode.
func set_sort_mode(mode: String) -> void:
	if SORT_MODES.has(mode):
		_current_sort = mode
		_refresh()


func _refresh() -> void:
	for child in item_list_container.get_children():
		child.queue_free()

	var owned: Dictionary = InventoryManager.get_all_items()
	var item_ids: Array = owned.keys()

	if _current_filter != "all":
		item_ids = item_ids.filter(func(id: String) -> bool: return ItemDatabase.get_category(id) == _current_filter)

	item_ids = _sort_ids(item_ids, owned)

	for item_id in item_ids:
		item_list_container.add_child(_build_row(item_id, owned[item_id]))


func _sort_ids(item_ids: Array, owned: Dictionary) -> Array:
	match _current_sort:
		"category":
			item_ids.sort_custom(func(a, b): return ItemDatabase.get_category(a) < ItemDatabase.get_category(b))
		"quantity":
			item_ids.sort_custom(func(a, b): return owned[a] > owned[b])
		_:
			item_ids.sort_custom(func(a, b): return ItemDatabase.get_display_name(a) < ItemDatabase.get_display_name(b))
	return item_ids


func _build_row(item_id: String, count: int) -> Control:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = "%s x%d" % [ItemDatabase.get_display_name(item_id), count]
	row.add_child(name_label)

	return row
