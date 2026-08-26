extends Node
class_name SpawnPointComponent
## SpawnPointComponent
##
## On scene entry, places the player's body at the PlayerSpawnPoint whose
## `spawn_id` matches `target_spawn_id`. Falls back to whatever position
## the Player node already has in the scene (its editor-placed position)
## if no matching marker is found, so this never silently teleports the
## player to (0,0).
##
## INTEGRATION HOOK (not wired yet - no region scenes exist to test
## against): when Scenes/Regions/* scenes exist, whatever triggers a
## region transition (e.g. RegionManager.travel_to_region) should set
## `target_spawn_id` on the Player instance BEFORE this resolves - for
## example immediately after SceneLoader's `scene_load_finished` signal,
## before the first frame renders. This script intentionally does not
## reach into RegionManager itself, to stay decoupled and testable in
## isolation.

@export var target_spawn_id: String = "default"


func resolve_and_place(body: Node2D) -> void:
	if body == null:
		return

	var markers := body.get_tree().get_nodes_in_group("spawn_points")
	for marker: Node in markers:
		if marker is PlayerSpawnPoint and marker.spawn_id == target_spawn_id:
			body.global_position = marker.global_position
			EventBus.player_spawned.emit(target_spawn_id)
			return

	push_warning(
		"SpawnPointComponent: no spawn point '%s' found in scene, keeping current position" % target_spawn_id
	)
