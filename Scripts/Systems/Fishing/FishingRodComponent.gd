extends Node
class_name FishingRodComponent
## FishingRodComponent
##
## Tracks whether the player currently has the fishing rod equipped.
## Equipping requires the "fishing_rod" item to already be in
## InventoryManager - this component never grants the item itself, it only
## gates equip/unequip and broadcasts the change via EventBus so animation
## and UI can react without holding a reference to this component.
##
## The one exception is FishingSpot (see Interaction/../Fishing/FishingSpot.gd),
## which needs a synchronous yes/no answer at the moment of interaction, so
## it queries this component directly via %FishingRodComponent - the same
## unique-name pattern Player.gd itself uses, not a new coupling style.
##
## PERSISTENCE: plugs into SavePositionComponent's existing provider
## pattern instead of registering its own SaveManager section, so equip
## state saves/loads as part of the same "player" save section. Player.gd
## calls `persistence.register_provider(fishing_rod)` once at startup.

const ROD_ITEM_ID := "fishing_rod"

signal equipped_changed(is_equipped: bool)

var _is_equipped: bool = false


func is_equipped() -> bool:
	return _is_equipped


## Wired to PlayerInputComponent.toggle_rod_pressed by Player.gd.
func toggle() -> void:
	if _is_equipped:
		_set_equipped(false)
		return
		
	var has_rod := InventoryManager.has_item(ROD_ITEM_ID)
	print("Has rod: ", has_rod, " | now equipped: ", _is_equipped)
		
	if not InventoryManager.has_item(ROD_ITEM_ID):
		EventBus.ui_notification_requested.emit("You don't have a fishing rod yet.", 2.0)
		return

	_set_equipped(true)

func _set_equipped(equipped: bool) -> void:
	if _is_equipped == equipped:
		return
	_is_equipped = equipped
	print("Equipped state is now: ", _is_equipped)
	equipped_changed.emit(equipped)
	EventBus.equipment_changed.emit(ROD_ITEM_ID if equipped else "")


## --- SavePositionComponent provider interface (get_save_state/apply_save_state) ---
func get_save_state() -> Dictionary:
	return {"rod_equipped": _is_equipped}


func apply_save_state(data: Dictionary) -> void:
	_set_equipped(data.get("rod_equipped", false))
