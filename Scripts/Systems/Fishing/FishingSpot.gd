extends Interactable
class_name FishingSpot
## FishingSpot
##
## A fishing-specific Interactable. Reuses Interactable's existing
## in-range detection, prompt text, and `enabled` gating (Open/Closed:
## extends rather than duplicates Interactable's logic) and adds exactly
## one rule on top: interacting only succeeds if the player currently has
## the fishing rod equipped.
##
## Does NOT implement the fishing minigame itself (casting, reeling,
## catch tables) - it only emits `EventBus.fishing_started`/`fishing_denied`
## so a future FishingSystem can own that gameplay without this script
## needing to change. Place one of these (as an Area2D) at each fishing
## spot in a region scene, same as any other Interactable.

## Unique id for this spot, used as the payload on fishing_started/denied
## signals (e.g. so a minigame system or analytics can tell spots apart).
@export var spot_id: String = "fishing_spot"


func _ready() -> void:
	super._ready()
	add_to_group("fishing_spots")


func interact(interactor: Node) -> void:
	if not enabled:
		return

	var rod := _get_rod_component(interactor)
	if rod == null or not rod.is_equipped():
		EventBus.fishing_denied.emit(spot_id, "rod_not_equipped")
		return

	interacted.emit(interactor)
	EventBus.fishing_started.emit(spot_id)


## Looks up the interacting player's FishingRodComponent via the same
## %UniqueName pattern Player.gd uses internally - this works regardless
## of where FishingSpot is instanced, since the unique name is scoped to
## the Player scene the component belongs to, not this node's scene.
func _get_rod_component(interactor: Node) -> FishingRodComponent:
	if interactor == null:
		return null
	return interactor.get_node_or_null("%FishingRodComponent") as FishingRodComponent
