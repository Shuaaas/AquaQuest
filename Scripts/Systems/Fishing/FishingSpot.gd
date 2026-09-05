extends Interactable
class_name FishingSpot
## FishingSpot
##
## A fishing-specific Interactable. Reuses Interactable's existing
## in-range detection, prompt text, and `enabled` gating (Open/Closed:
## extends rather than duplicates Interactable's logic) and adds fishing-
## specific rules on top: an optional required quest, and requiring the
## player to have the fishing rod equipped.
##
## Does NOT implement the fishing flow itself (casting, waiting, the bite,
## the question, catch/miss resolution) - it only emits
## `EventBus.fishing_started`/`fishing_denied` so FishingManager (an
## autoload) can own that entire flow without this script needing to
## change. Place one of these (as an Area2D) at each fishing spot in a
## region scene, same as any other Interactable.

## Unique id for this spot, used as the payload on fishing_started/denied
## signals (e.g. so a minigame system or analytics can tell spots apart).
@export var spot_id: String = "fishing_spot"

## Optional. If set, interact() requires this quest to be "active" before
## fishing is allowed at all - this is the "Player accepts a quest" gate
## from the Phase 5 flow. Leave empty ("") for a spot anyone can fish at
## regardless of quest state (e.g. a tutorial/free-practice spot).
@export var required_quest_id: String = ""

## Optional. Item ids FishingManager can award on a successful catch here.
## Leave empty to fall back to FishingManager's generic placeholder fish -
## this is what makes the system "easily expandable for multiple fish
## species" per-spot, without FishingManager needing to know this spot
## exists ahead of time (it looks this up by spot_id only at the moment
## a catch resolves).
@export var possible_fish_ids: Array[String] = []


func _ready() -> void:
	super._ready()
	add_to_group("fishing_spots")


func interact(interactor: Node) -> void:
	if not enabled:
		return

	if required_quest_id != "" and QuestManager.get_quest_state(required_quest_id) != "active":
		print("Quest gate blocked - required: ", required_quest_id, " | actual state: ", QuestManager.get_quest_state(required_quest_id))
		EventBus.fishing_denied.emit(spot_id, "quest_not_active")
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
