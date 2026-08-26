extends Node
## UIManager (Autoload Singleton)
##
## Manages a stack of full-screen/overlay UI scenes (HUD, menus, dialogue
## box, exam screen, notifications) so only one system decides what's on
## top and z-order/input handling stays consistent. UIManager holds a
## reference to a root CanvasLayer that must exist in the currently loaded
## scene (set via register_ui_root) - it does not create UI itself, so
## artists/UI devs remain free to build screens however they like.

var _ui_root: CanvasLayer = null
var _screen_stack: Array[Control] = []

# screen_id -> PackedScene, populated by a UI registry loader at boot.
var _screen_registry: Dictionary = {}


func register_ui_root(root: CanvasLayer) -> void:
	_ui_root = root


func register_screen(screen_id: String, packed_scene: PackedScene) -> void:
	_screen_registry[screen_id] = packed_scene


func push_screen(screen_id: String) -> Control:
	if _ui_root == null:
		push_error("UIManager: no UI root registered, cannot push '%s'" % screen_id)
		return null
	if not _screen_registry.has(screen_id):
		push_error("UIManager: unknown screen_id '%s'" % screen_id)
		return null

	var instance: Control = _screen_registry[screen_id].instantiate()
	_ui_root.add_child(instance)
	_screen_stack.append(instance)
	EventBus.ui_screen_pushed.emit(screen_id)
	return instance


func pop_screen() -> void:
	if _screen_stack.is_empty():
		return
	var top: Control = _screen_stack.pop_back()
	var screen_id: String = top.name
	top.queue_free()
	EventBus.ui_screen_popped.emit(screen_id)


func pop_all() -> void:
	while not _screen_stack.is_empty():
		pop_screen()


func show_notification(message: String, duration: float = 2.0) -> void:
	EventBus.ui_notification_requested.emit(message, duration)


func has_screen_open(screen_id: String) -> bool:
	for screen: Control in _screen_stack:
		if screen.name == screen_id:
			return true
	return false
