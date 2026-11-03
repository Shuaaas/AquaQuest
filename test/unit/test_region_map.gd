extends GutTest
const REGION := preload("res://test/fixtures/save_region.tscn")
const MAP := preload("res://Scene/UI/RegionMapUI.tscn")
const WORLD := preload("res://Scene/UI/WorldMapUI.tscn")
const MINI := preload("res://Scene/UI/MiniMapUI.tscn")
const LOCATION := preload("res://Scripts/Systems/Map/MapLocation.gd")
var container: Node2D
var region: Node2D
var player: Player
var host: Control
var map: Control
var world: Control
var mini: Control
var saved: Dictionary
var sections: Array[Dictionary]


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	saved = {
		"definitions": RegionManager._region_definitions.duplicate(true),
		"region": RegionManager.current_region_id,
		"spawn": RegionManager.pending_spawn_id,
		"state": GameManager.current_state,
		"quests": QuestManager._get_save_data().duplicate(true),
		"regions": RegionManager._get_save_data().duplicate(true)
	}
	sections = SaveManager._registered_sections.duplicate()
	GameManager.current_state = GameManager.GameState.PLAYING
	RegionManager.current_region_id = "region_1"
	RegionManager._region_definitions["region_1"]["scene_path"] = REGION.resource_path
	RegionManager.pending_spawn_id = "default"
	container = Node2D.new()
	add_child(container)
	container.add_to_group("region_container")
	region = REGION.instantiate()
	container.add_child(region)
	player = region.get_node("player")
	host = Control.new()
	host.size = Vector2(1200, 760)
	add_child(host)
	world = WORLD.instantiate()
	world.name = "WorldMapUI"
	host.add_child(world)
	world.add_to_group("gameplay_overlay")
	map = MAP.instantiate()
	host.add_child(map)
	map.add_to_group("gameplay_overlay")
	mini = MINI.instantiate()
	host.add_child(mini)
	await settle()


func after_each() -> void:
	map._return_from_world = false
	map.close_map()
	world.close_map()
	host.free()
	container.free()
	GameManager.set_paused(false)
	SaveManager._registered_sections = sections
	RegionManager._region_definitions = saved.definitions
	RegionManager._apply_save_data(saved.regions)
	RegionManager.current_region_id = saved.region
	RegionManager.pending_spawn_id = saved.spawn
	QuestManager._apply_save_data(saved.quests)
	GameManager.current_state = saved.state
	await get_tree().process_frame


func settle() -> void:
	for frame in 12:
		await get_tree().process_frame


func test_minimap_click_opens_one_region_view_and_releases_its_pause() -> void:
	var position := player.global_position
	var before := QuestManager._get_save_data().duplicate(true)
	mini.get_node("%OpenRegionMap").pressed.emit()
	await settle()
	assert_true(map.visible)
	assert_false(world.visible)
	assert_true(get_tree().paused)
	assert_eq(map.viewport.world_2d, player.get_world_2d())
	assert_eq(map.surface.player_position, position)
	EventBus.region_map_open_requested.emit()
	assert_eq(host.find_children("RegionMapUI", "", false, false).size(), 1)
	assert_eq(QuestManager._get_save_data(), before)
	assert_eq(player.global_position, position)
	map.close_map()
	assert_false(get_tree().paused)
	assert_eq(map.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_world_map_handoff_returns_to_region_without_losing_pause_ownership() -> void:
	assert_true(map.open_map())
	map.get_node("%WorldButton").pressed.emit()
	assert_false(map.visible)
	assert_true(world.visible)
	assert_true(get_tree().paused)
	world.close_map()
	await settle()
	assert_true(map.visible)
	assert_false(world.visible)
	assert_true(get_tree().paused)
	map.get_node("%CloseButton").pressed.emit()
	assert_false(get_tree().paused)


func test_foreign_pause_and_other_overlays_cannot_be_released_by_region_map() -> void:
	GameManager.set_paused(true)
	assert_false(map.open_map())
	map.close_map()
	assert_true(get_tree().paused)
	GameManager.set_paused(false)
	world.open_map()
	assert_false(map.open_map())
	map.close_map()
	assert_true(get_tree().paused)
	world.close_map()


func test_region_query_can_show_all_markers_without_changing_minimap_limit() -> void:
	for index in 17:
		var location := LOCATION.new()
		location.title = "Test location %d" % index
		region.add_child(location)
		location.position = Vector2(index * 20, 50)
	assert_lte(MapManager.get_markers(region, player, INF).size(), 12)
	assert_gte(MapManager.get_markers(region, player, INF, 0).size(), 17)
	map.open_map()
	assert_gte(map.surface.markers.size(), 17)


func test_pan_zoom_player_projection_and_pointer_input_do_not_move_player() -> void:
	map.open_map()
	await settle()
	var position := player.global_position
	map.zoom_at(2, map.surface.size / 2)
	assert_eq(float(map.zoom_level), 2.0)
	var old: Vector2 = map.map_center
	map.pan(Vector2(50, 0))
	assert_true(map.map_center.x <= old.x)
	assert_eq(map.surface.project(map.map_center), map.surface.size / 2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	map.surface._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(20, 0)
	map.surface._gui_input(drag)
	assert_true(map.surface._dragging)
	map.close_map()
	assert_false(map.surface._dragging)
	assert_eq(player.global_position, position)


func test_phone_landscape_bounds_and_escape() -> void:
	map.open_map()
	for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844), Vector2(360, 740)]:
		host.size = dimensions
		await settle()
		assert_true(
			Rect2(Vector2.ZERO, dimensions).encloses(map.get_node("%Frame").get_rect()),
			str(dimensions)
		)
		assert_gt(map.surface.size.y, 80.0)
		for name in ["WorldButton", "CloseButton", "ZoomIn", "ZoomOut", "CenterButton"]:
			assert_gte(map.get_node("%" + name).size.y, 48.0)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	map._input(escape)
	assert_false(map.visible)
	assert_false(get_tree().paused)


func test_region_departure_closes_map_and_disables_rendering() -> void:
	map.open_map()
	EventBus.region_changed.emit("region_1", "region_2")
	assert_false(map.visible)
	assert_false(get_tree().paused)
	assert_eq(map.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_touch_drag_is_single_input_and_marker_selection_uses_existing_data() -> void:
	map.open_map()
	await settle()
	map.zoom_at(2, map.surface.size / 2)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	map.surface._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(10, 0)
	map.surface._gui_input(drag)
	var center: Vector2 = map.map_center
	var emulated := InputEventMouseMotion.new()
	emulated.device = -1
	emulated.relative = Vector2(10, 0)
	map.surface._gui_input(emulated)
	assert_eq(map.map_center, center)
	map.surface.markers = [
		{"position": map.map_center, "title": "Existing location", "kind": "location"}
	]
	map.surface._pick(map.surface.size / 2)
	assert_eq(map.get_node("%Selection").text, "Existing location")


func test_keyboard_zoom_and_pan_work_while_toolbar_has_focus() -> void:
	map.open_map()
	await settle()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_PLUS
	map._input(key)
	assert_gt(map.zoom_level, 1.0)
	var before: Vector2 = map.map_center
	key.keycode = KEY_RIGHT
	map._input(key)
	assert_true(map.map_center.x >= before.x)
