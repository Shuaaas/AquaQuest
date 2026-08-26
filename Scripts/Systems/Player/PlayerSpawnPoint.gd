extends Marker2D
class_name PlayerSpawnPoint
## PlayerSpawnPoint
##
## Drop one of these anywhere in a region/level scene to mark a valid
## player spawn location. Give each a unique `spawn_id` within its scene
## (e.g. "default", "north_gate", "dock_exit"). SpawnPointComponent finds
## these at runtime by group + id match - nothing hardcodes a scene path
## to a specific marker.

@export var spawn_id: String = "default"


func _ready() -> void:
	add_to_group("spawn_points")
