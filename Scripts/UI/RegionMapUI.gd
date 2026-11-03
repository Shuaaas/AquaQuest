extends Control
## Read-only current-region overview. Shares the live World2D without cloning game nodes.
var _owns_pause := false
var _previous_focus: WeakRef
var _world_map: Control
var _return_from_world := false
var _region: Node
var _player: Player
var world_bounds := Rect2(-512, -512, 1024, 1024)
var map_center := Vector2.ZERO
var zoom_level := 1.0
var _scale := 1.0
@onready var surface: Control = %Surface
@onready var viewport: SubViewport = %MapViewport
@onready var camera: Camera2D = %MapCamera


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	%Terrain.texture = viewport.get_texture()
	%CloseButton.pressed.connect(close_map)
	%WorldButton.pressed.connect(_open_world)
	%CenterButton.pressed.connect(center_on_player)
	%ZoomIn.pressed.connect(zoom_at.bind(1.25, Vector2(-1, -1)))
	%ZoomOut.pressed.connect(zoom_at.bind(0.8, Vector2(-1, -1)))
	surface.pan_requested.connect(pan)
	surface.zoom_requested.connect(zoom_at)
	surface.marker_selected.connect(func(marker): %Selection.text = str(marker.title))
	resized.connect(_layout)
	%Frame.minimum_size_changed.connect(_layout.call_deferred)
	surface.resized.connect(_sync_view)
	EventBus.region_map_open_requested.connect(open_map)
	EventBus.map_data_changed.connect(_refresh_markers)
	EventBus.scene_load_started.connect(_on_departure)
	EventBus.region_changed.connect(_on_departure)
	_world_map = get_node_or_null("../WorldMapUI")
	if _world_map != null:
		_world_map.visibility_changed.connect(_on_world_visibility)
	_layout.call_deferred()


func open_map() -> bool:
	if visible:
		return true
	if (
		get_tree().paused
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or DialogueManager.is_active
		or FishingManager.is_fishing()
		or MapManager.has_blocking_overlay(self)
	):
		return false
	if not GameManager.current_state in [GameManager.GameState.BOOT, GameManager.GameState.PLAYING]:
		return false
	_region = MapManager.get_current_region_root()
	_player = MapManager.get_local_player(_region) as Player
	if _player == null:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	world_bounds = _measure_region(_region, _player.global_position)
	map_center = world_bounds.get_center()
	zoom_level = 1.0
	viewport.world_2d = _player.get_world_2d()
	var info := MapManager.get_region_info(RegionManager.current_region_id)
	%RegionTitle.text = (
		"%s · Region Map"
		% str(info.get("name", RegionManager.current_region_id.replace("_", " ").capitalize()))
	)
	%Selection.text = "You · Current position"
	_owns_pause = true
	GameManager.set_paused(true)
	show()
	_refresh_markers()
	_layout()
	_sync_view.call_deferred()
	%CloseButton.grab_focus()
	return true


func close_map() -> void:
	hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.world_2d = World2D.new()
	surface.reset_input()
	if _owns_pause:
		_owns_pause = false
		GameManager.set_paused(false)
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _exit_tree() -> void:
	if _owns_pause:
		_owns_pause = false
		GameManager.set_paused(false)


func _open_world() -> void:
	close_map()
	EventBus.world_map_open_requested.emit()
	_return_from_world = is_instance_valid(_world_map) and _world_map.visible


func _on_world_visibility() -> void:
	if _return_from_world and not _world_map.visible:
		_return_from_world = false
		open_map.call_deferred()


func _on_departure(_value: String, _destination: String = "") -> void:
	_return_from_world = false
	close_map()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_M
		and not event.ctrl_pressed
	):
		_open_world()
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		var handled := true
		match event.keycode:
			KEY_LEFT:
				pan(Vector2(60, 0))
			KEY_RIGHT:
				pan(Vector2(-60, 0))
			KEY_UP:
				pan(Vector2(0, 60))
			KEY_DOWN:
				pan(Vector2(0, -60))
			KEY_SPACE:
				center_on_player()
			KEY_PLUS, KEY_EQUAL:
				zoom_at(1.25, Vector2(-1, -1))
			KEY_MINUS:
				zoom_at(0.8, Vector2(-1, -1))
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _layout() -> void:
	if not is_node_ready():
		return
	var bounds := Rect2(Vector2.ZERO, size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var transform := get_viewport().get_screen_transform().affine_inverse()
		var origin := Vector2(DisplayServer.window_get_position())
		var start := transform * (Vector2(safe.position) - origin)
		bounds = bounds.intersection(Rect2(start, transform * (Vector2(safe.end) - origin) - start))
	bounds = bounds.grow(-12)
	%Frame.position = bounds.position
	%Frame.size = bounds.size
	%Toolbar.add_theme_constant_override("separation", 6 if size.x < 500 else 8)
	%WorldButton.custom_minimum_size.x = 72 if size.x < 500 else 120
	%CloseButton.custom_minimum_size.x = 64 if size.x < 500 else 80
	%Help.visible = size.y >= 450
	%Legend.visible = size.y >= 450
	%RegionTitle.add_theme_font_size_override(
		"font_size", 18 if size.x < 500 or size.y < 450 else 24
	)
	_sync_view()


func _sync_view() -> void:
	if not is_node_ready() or not visible or not is_instance_valid(_player):
		return
	var dimensions: Vector2 = surface.size.max(Vector2(1, 1))
	var fit := minf(dimensions.x / world_bounds.size.x, dimensions.y / world_bounds.size.y)
	_scale = fit * zoom_level
	var extent := dimensions / maxf(_scale, 0.0001) / 2
	for axis in 2:
		map_center[axis] = (
			world_bounds.get_center()[axis]
			if extent[axis] * 2 >= world_bounds.size[axis]
			else clampf(
				map_center[axis],
				world_bounds.position[axis] + extent[axis],
				world_bounds.end[axis] - extent[axis]
			)
		)
	var ratio := minf(1, minf(1280.0 / dimensions.x, 720.0 / dimensions.y))
	viewport.size = Vector2i((dimensions * ratio).round()).max(Vector2i.ONE)
	camera.position = map_center
	camera.zoom = Vector2.ONE * _scale * ratio
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.center = map_center
	surface.pixels_per_world = _scale
	surface.player_position = _player.global_position
	surface.player_facing = _player.movement.facing
	surface.queue_redraw()


func pan(screen_delta: Vector2) -> void:
	map_center -= screen_delta / maxf(_scale, 0.0001)
	_sync_view()


func zoom_at(factor: float, point: Vector2) -> void:
	if point.x < 0:
		point = surface.size / 2
	var world := map_center + (point - surface.size / 2) / maxf(_scale, 0.0001)
	var old := zoom_level
	zoom_level = clampf(zoom_level * factor, 1, 8)
	map_center = world - (point - surface.size / 2) / maxf(_scale * (zoom_level / old), 0.0001)
	_sync_view()


func center_on_player() -> void:
	if is_instance_valid(_player):
		map_center = _player.global_position
		_sync_view()


func _refresh_markers() -> void:
	if not visible:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_region):
		close_map()
		return
	surface.markers = MapManager.get_markers(_region, _player, INF, 0)
	surface.queue_redraw()


func _measure_region(region: Node, player: Vector2) -> Rect2:
	var bounds := Rect2(player - Vector2(64, 64), Vector2(128, 128))
	for node in region.find_children("*", "Node2D", true, false):
		if node is TileMapLayer and node.tile_set != null and not node.get_used_rect().has_area():
			continue
		if node is TileMapLayer and node.tile_set != null:
			var used: Rect2i = node.get_used_rect()
			var half := Vector2(node.tile_set.tile_size) / 2
			var first: Vector2 = node.map_to_local(used.position) - half
			var last: Vector2 = node.map_to_local(used.end - Vector2i.ONE) + half
			for corner in [first, last, Vector2(first.x, last.y), Vector2(last.x, first.y)]:
				bounds = bounds.expand(node.to_global(corner))
		elif node is NPC or node is FishingSpot or node is RegionExit:
			bounds = bounds.expand(node.global_position)
	return bounds.grow(48)
