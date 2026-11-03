extends GutTest
## Integration checks against the real Region 1 scene and player collision shape.
const REGION := preload("res://Scene/Regions/region_1.tscn")
var region: Node2D
var player: Player
var reachable: Array[Vector2i] = []
var parents: Dictionary = {}
var sections_before: Array[Dictionary]
var spawn_before: String
var state_before: int
var inventory_before: Dictionary
var quests_before: Dictionary
var shop_before: String


func before_all() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sections_before = SaveManager._registered_sections.duplicate()
	spawn_before = RegionManager.pending_spawn_id
	state_before = GameManager.current_state
	inventory_before = InventoryManager._get_save_data().duplicate(true)
	quests_before = QuestManager._get_save_data().duplicate(true)
	shop_before = ShopManager._current_shop_id
	RegionManager.pending_spawn_id = "default"
	QuestManager._apply_save_data({})
	region = REGION.instantiate()
	add_child(region)
	player = region.get_node("player")
	player.input.set_active(false)
	player.movement.set_physics_process(false)
	for i in range(4):
		await get_tree().physics_frame
	_build_routes()


func after_all() -> void:
	if DialogueManager.is_active:
		DialogueManager._end_dialogue()
	FishingManager._reset_to_idle()
	GameManager.set_paused(false)
	region.free()
	SaveManager._registered_sections = sections_before
	RegionManager.pending_spawn_id = spawn_before
	InventoryManager._apply_save_data(inventory_before)
	QuestManager._apply_save_data(quests_before)
	ShopManager._current_shop_id = shop_before
	GameManager.current_state = state_before
	await get_tree().process_frame


func _build_routes() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = 1
	query.collide_with_areas = false
	var seen: Dictionary = {Vector2i.ZERO: true}
	reachable = [Vector2i.ZERO]
	var index := 0
	while index < reachable.size():
		var cell := reachable[index]
		index += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if next.x < -58 or next.x > 19 or next.y < -15 or next.y > 64 or seen.has(next):
				continue
			query.transform.origin = Vector2(next * 16) + Vector2(0, -10)
			if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			if player.test_move(Transform2D(0, Vector2(cell * 16)), Vector2(direction * 16)):
				continue
			seen[next] = true
			parents[next] = cell
			reachable.append(next)


func _approach(target: Vector2) -> Vector2i:
	var closest := Vector2i.ZERO
	var distance := INF
	for cell in reachable:
		var current := Vector2(cell * 16).distance_squared_to(target)
		if current < distance:
			distance = current
			closest = cell
	return closest


func _walk_to(target: Vector2) -> void:
	var cell := _approach(target)
	var path: Array[Vector2i] = [cell]
	while parents.has(cell):
		cell = parents[cell]
		path.append(cell)
	path.reverse()
	player.position = Vector2.ZERO
	for point in path:
		var collision := player.move_and_collide(Vector2(point * 16) - player.position)
		assert_null(collision, "Route must remain passable at " + str(point * 16))
	for i in range(3):
		await get_tree().physics_frame


func test_original_gameplay_anchors_and_default_spawn_are_preserved() -> void:
	assert_eq(region.get_node("DefaultSpawn").position, Vector2.ZERO)
	assert_eq(region.get_node("NPC_teacher").position, Vector2(-458, 84))
	assert_eq(region.get_node("Npc_examiner_santaigo").position, Vector2(-153, -44))
	assert_eq(region.get_node("npc_merchant_lola").position, Vector2(133, -38))
	assert_almost_eq(
		region.get_node("FishingSpot").position, Vector2(-626, 157), Vector2(0.001, 0.001)
	)
	assert_eq(region.get_node("RegionExit").position, Vector2(-232, -98))
	assert_eq(region.get_node("RegionExit").destination_region_id, "region_2")
	assert_eq(region.get_node("FishingSpot").location_id, "region1_dock_north")


func test_player_can_walk_from_spawn_to_every_required_location() -> void:
	assert_gt(reachable.size(), 0)
	for name in ["NPC_teacher", "Npc_examiner_santaigo", "npc_merchant_lola", "RegionExit"]:
		var target = region.get_node(name)
		assert_lt(Vector2(_approach(target.position) * 16).distance_to(target.position), 24.0, name)
		await _walk_to(target.position)
	var fishing = region.get_node("FishingSpot")
	await _walk_to(fishing.position)
	assert_true(
		player.interaction._in_range.has(fishing),
		"Dock must be inside the existing fishing interaction area"
	)


func test_existing_npc_interaction_detection_and_dialogue_still_work() -> void:
	for name in ["NPC_teacher", "Npc_examiner_santaigo", "npc_merchant_lola"]:
		var npc = region.get_node(name)
		await _walk_to(npc.position)
		assert_true(player.interaction._in_range.has(npc), name)
		player.interaction.try_interact()
		assert_true(DialogueManager.is_active, name)
		DialogueManager._end_dialogue()
		# Examiner remains gated by the original incomplete quest.
		GameManager.set_paused(false)


func test_fishing_quest_gate_and_equipped_rod_still_start_existing_flow() -> void:
	var fishing = region.get_node("FishingSpot")
	await _walk_to(fishing.position)
	watch_signals(EventBus)
	player.interaction.try_interact()
	assert_signal_emitted_with_parameters(
		EventBus, "fishing_denied", [fishing.spot_id, "quest_not_active"]
	)
	QuestManager._apply_save_data(
		{"quest_states": {"learn_post_harvest_basics": {"state": "active"}}}
	)
	InventoryManager.add_item("fishing_rod")
	player.fishing_rod.toggle()
	player.interaction.try_interact()
	assert_signal_emitted_with_parameters(EventBus, "fishing_started", [fishing.spot_id])
	FishingManager._reset_to_idle()


func test_new_outer_boundaries_block_escape() -> void:
	var query := PhysicsRayQueryParameters2D.new()
	query.collision_mask = 1
	for segment in [
		[Vector2(-900, 0), Vector2(-960, 0)],
		[Vector2(300, 0), Vector2(350, 0)],
		[Vector2(-700, -230), Vector2(-700, -290)],
		[Vector2(-700, 1020), Vector2(-700, 1070)]
	]:
		query.from = segment[0]
		query.to = segment[1]
		assert_false(player.get_world_2d().direct_space_state.intersect_ray(query).is_empty())


func test_existing_movement_controller_moves_and_stops_on_village_ground() -> void:
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.movement.set_run_input(false)
	player.movement.set_move_input(Vector2.LEFT)
	for i in range(30):
		player.movement._physics_process(1.0 / 60.0)
	assert_lt(player.position.x, -40.0)
	assert_almost_eq(player.position.y, 0.0, 0.01)
	player.movement.set_move_input(Vector2.ZERO)
	for i in range(15):
		player.movement._physics_process(1.0 / 60.0)
	assert_eq(player.velocity, Vector2.ZERO)


func test_environment_uses_unscaled_pack_art_and_valid_atlas_regions() -> void:
	var environment := region.get_node("VillageEnvironment")
	for node in environment.find_children("*", "", true, false):
		if node is Sprite2D:
			assert_eq(node.scale, Vector2.ONE, str(node.get_path()))
			if node.texture is AtlasTexture:
				var atlas := node.texture as AtlasTexture
				assert_true(atlas.atlas.resource_path.begins_with("res://Assets/Environment/"))
				assert_true(
					Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region),
					str(node.get_path())
				)
		if node is TileMapLayer:
			assert_eq(node.tile_set.tile_size, Vector2i(16, 16))
			var inspected: Dictionary = {}
			for cell in node.get_used_cells():
				var source_id: int = node.get_cell_source_id(cell)
				var coords: Vector2i = node.get_cell_atlas_coords(cell)
				var key := str(source_id) + str(coords)
				if inspected.has(key):
					continue
				inspected[key] = true
				var source := node.tile_set.get_source(source_id) as TileSetAtlasSource
				assert_not_null(source)
				if source != null:
					assert_eq(source.texture_region_size, Vector2i(16, 16))
					assert_true(
						source.texture.resource_path.begins_with("res://Assets/Environment/")
					)
					assert_true(
						Rect2i(Vector2i.ZERO, source.texture.get_size()).encloses(
							Rect2i(coords * 16, Vector2i(16, 16))
						)
					)
		if node is Polygon2D:
			assert_true(node.texture.resource_path.begins_with("res://Assets/Environment/"))
			for i in range(node.polygon.size()):
				var next: int = (i + 1) % node.polygon.size()
				assert_almost_eq(
					node.polygon[i].distance_to(node.polygon[next]),
					node.uv[i].distance_to(node.uv[next]),
					0.001
				)
