extends Node
## SceneLoader (Autoload Singleton)
##
## Wraps Godot's ResourceLoader background-loading API so scene changes
## don't hitch on lower-end Android devices. Emits progress via EventBus so
## a loading-screen UI can subscribe without SceneLoader knowing the UI
## exists (Dependency Inversion again - loader doesn't import UI scenes).

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
			get_tree().change_scene_to_packed(packed_scene)
			_is_loading = false
			set_process(false)
			EventBus.scene_load_finished.emit(_target_scene_path)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneLoader: failed to load scene %s" % _target_scene_path)
			_is_loading = false
			set_process(false)
		_:
			pass # still loading, keep polling next frame
