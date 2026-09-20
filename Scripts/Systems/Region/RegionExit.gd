extends Area2D
class_name RegionExit
## RegionExit
##
## A walk-into trigger for traveling between regions - a door, path edge,
## boat, or similar. Deliberately NOT an Interactable subclass: FishingSpot
## and NPC both require the player to press interact while in range;
## this fires automatically the instant the player's physical body enters
## it, since "walking to the edge of the map" is a different interaction
## pattern than "approaching something and pressing a button."
##
## SETUP:
##   - CollisionShape2D sized to the doorway/path/exit point
##   - Collision Layer: none (passive, doesn't need to be detected)
##   - Collision Mask: layer 2 (player) - detects the Player's physical
##     CharacterBody2D directly via body_entered, NOT the Area2D-vs-Area2D
##     pattern InteractionComponent/Interactable use
##   - Monitoring: On (needs to detect), Monitorable: not required
##
## Set `destination_region_id` to a region defined in Data/JSON/Regions/,
## and `destination_spawn_id` to a PlayerSpawnPoint's spawn_id in THAT
## region's scene - e.g. a RegionExit at Region 1's east edge would set
## destination_spawn_id to whatever marks Region 2's WEST entrance, so
## the player arrives facing the right direction, not always at that
## region's generic "default" spawn.

## Must match a region_id in Data/JSON/Regions/.
@export var destination_region_id: String = ""

## Must match a PlayerSpawnPoint's spawn_id in the DESTINATION region's
## scene. Leave as "default" if that region only has one spawn point.
@export var destination_spawn_id: String = "default"

## Optional. If set, this exit requires this quest to be active before
## travel is allowed - same optional-gate pattern FishingSpot already
## uses for required_quest_id. Leave empty for an always-open exit.
@export var required_quest_id: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return

	if destination_region_id == "":
		push_warning("RegionExit: destination_region_id not set on %s" % name)
		return

	if required_quest_id != "" and QuestManager.get_quest_state(required_quest_id) != "active":
		UIManager.show_notification("You can't go there yet.", 2.0)
		return

	if not RegionManager.is_region_unlocked(destination_region_id):
		UIManager.show_notification("That area hasn't been unlocked yet.", 2.0)
		return

	RegionManager.travel_to_region(destination_region_id, destination_spawn_id)
