extends Node
## SceneLoader (Autoload Singleton)
##
## Wraps Godot's ResourceLoader background-loading API so scene changes
## don't hitch on lower-end Android devices. Emits progress via EventBus so
## a loading-screen UI can subscribe without SceneLoader knowing the UI
## exists (Dependency Inversion - loader doesn't import UI scenes).
##
## IMPORTANT: this does NOT use get_tree().change_scene_to_packed(). That
## call replaces the ENTIRE scene tree, which would destroy a persistent
## HUD/CanvasLayer (e.g. FishingUI) every time the player changes regions.
## Instead, this looks up a node in the "region_container" group (expected
## to live inside your persistent Main.tscn, alongside a CanvasLayer for
## HUD) and swaps ONLY that node's children. Main.tscn itself, and
## anything under its CanvasLayer, is never touched.

var _target_scene_path: String = ""
var _is_loading: bool = false


func change_scene(scene_path: String) -> void:
	if _is_loading:
		push_warning("SceneLoader: load already in progress, ignoring request for %s" % scene_path)
		return

	_target_scene_path = scene_path
	_is_loading = true

	EventBus.scene_load_requested.emit(scene_path)
	ResourceLoader.load_threaded_request(scene_path)
	EventBus.scene_load_started.emit(scene_path)

	set_process(true)


func _process(_delta: float) -> void:
	if not _is_loading:
		set_process(false)
		return

	var status := ResourceLoader.load_threaded_get_status(_target_scene_path)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene_path)
			_swap_into_region_container(packed_scene)
			_is_loading = false
			set_process(false)
			EventBus.scene_load_finished.emit(_target_scene_path)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneLoader: failed to load scene %s" % _target_scene_path)
			_is_loading = false
			set_process(false)
		_:
			pass # still loading, keep polling next frame


## Finds the persistent region container (a node in the "region_container"
## group, expected to live inside Main.tscn) and replaces its children with
## the newly loaded region scene. Anything outside this container - the
## CanvasLayer/HUD, other autoload-driven UI - is left completely alone.
func _swap_into_region_container(packed_scene: PackedScene) -> void:
	var container := get_tree().get_first_node_in_group("region_container")
	if container == null:
		push_error("SceneLoader: no node found in group 'region_container' - is Main.tscn set as the Main Scene, and does it have a node added to that group?")
		return

	for child in container.get_children():
		child.queue_free()

	var new_region: Node = packed_scene.instantiate()
	container.add_child(new_region)
