extends Control
## Lightweight live terrain viewport + independent navigation marker overlay.

@export_range(80, 1000, 10) var world_radius: float = 280.0

var _elapsed: float = 0.0

@onready var map_viewport: SubViewport = %MapViewport
@onready var map_camera: Camera2D = %MapCamera
@onready var terrain: TextureRect = %Terrain
@onready var surface: Control = %MarkerSurface
@onready var region_label: Label = %RegionLabel
@onready var map_button: Button = %MapButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	terrain.texture = map_viewport.get_texture()
	map_button.pressed.connect(_open_map)
	EventBus.game_paused.connect(_on_paused)
	EventBus.dialogue_started.connect(_on_activity_started)
	EventBus.fishing_cast_started.connect(_on_activity_started)
	refresh()


func _open_map() -> void:
	EventBus.world_map_open_requested.emit()


func _process(delta: float) -> void:
	if _blocked():
		_hide_map()
		_elapsed = 0.1
		return
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0
		refresh()


func refresh() -> void:
	var region := MapManager.get_current_region_root()
	var player := MapManager.get_local_player(region)
	visible = player != null and not _blocked()
	if not visible:
		_hide_map()
		return
	var view_size := Vector2i(maxi(int(surface.size.x), 16), maxi(int(surface.size.y), 16))
	map_viewport.size = view_size
	map_viewport.world_2d = player.get_world_2d()
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_camera.position = player.global_position
	map_camera.zoom = Vector2.ONE * float(view_size.x) / (world_radius * 2)
	surface.player_position = player.global_position
	surface.radius = world_radius
	surface.markers = MapManager.get_markers(region, player, world_radius)
	surface.queue_redraw()
	region_label.text = RegionManager.current_region_id.replace("_", " ").capitalize()


func _blocked() -> bool:
	return (
		get_tree().paused
		or DialogueManager.is_active
		or FishingManager.is_fishing()
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or MapManager.has_blocking_overlay()
	)


func _hide_map() -> void:
	hide()
	surface.markers = []
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _on_paused(paused: bool) -> void:
	if paused:
		_hide_map()
	_elapsed = 0.1


func _on_activity_started(_id: String) -> void:
	_hide_map()
