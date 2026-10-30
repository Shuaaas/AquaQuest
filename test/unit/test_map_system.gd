extends GutTest

const REGION_SCENE := preload("res://test/fixtures/save_region.tscn")
const WORLD_SCENE := preload("res://Scene/UI/WorldMapUI.tscn")
const MINI_SCENE := preload("res://Scene/UI/MiniMapUI.tscn")
const NPC_SCENE := preload("res://Scene/NPC/Npc_teacher_ana.tscn")
const FISHING_SCENE := preload("res://Scene/Regions/fishing_spot.tscn")
const EXIT_SCENE := preload("res://Scene/Door/region_exit.tscn")
const NAVIGATION := preload("res://Scripts/Systems/Map/MapNavigation.gd")
const LOCATION := preload("res://Scripts/Systems/Map/MapLocation.gd")
const MAIN_SCRIPT := preload("res://Scripts/Managers/main.gd")

var container: Node2D
var region: Node2D
var player: Player
var npc: NPC
var spot: FishingSpot
var exit: RegionExit
var original: Dictionary
var original_sections: Array[Dictionary]
var original_viewport: Vector2i
var save_slot: int = -1
var original_slot: int


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = {
		"regions": RegionManager._get_save_data().duplicate(true),
		"definitions": RegionManager._region_definitions.duplicate(true),
		"quests": QuestManager._get_save_data().duplicate(true),
		"exam": ExamManager._get_save_data().duplicate(true),
		"codex": CodexManager._get_save_data().duplicate(true),
		"state": GameManager.current_state,
	}
	original_sections = SaveManager._registered_sections.duplicate()
	original_viewport = get_tree().root.size
	original_slot = SaveManager.current_slot
	GameManager.current_state = GameManager.GameState.PLAYING
	RegionManager.current_region_id = "region_1"
	RegionManager._unlocked_regions = {"region_1": true}
	RegionManager._region_definitions["region_1"]["scene_path"] = REGION_SCENE.resource_path
	QuestManager._quest_states = {}
	ExamManager._apply_save_data({})
	container = Node2D.new()
	add_child(container)
	container.add_to_group("region_container")
	region = REGION_SCENE.instantiate()
	container.add_child(region)
	player = region.get_node("player")
	player.global_position = Vector2(100, 100)
	npc = NPC_SCENE.instantiate()
	region.add_child(npc)
	npc.position = Vector2(140, 140)
	spot = FISHING_SCENE.instantiate()
	region.add_child(spot)
	spot.position = Vector2(200, 160)
	exit = EXIT_SCENE.instantiate()
	region.add_child(exit)
	exit.position = Vector2(250, 100)


func after_each() -> void:
	get_tree().paused = false
	GameManager.is_paused = false
	container.free()
	SaveManager._registered_sections = original_sections
	SaveManager.current_slot = original_slot
	if save_slot >= 0:
		var path := SaveManager._slot_path(save_slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		save_slot = -1
	RegionManager.current_region_id = original["regions"]["current_region_id"]
	RegionManager._unlocked_regions = original["regions"]["unlocked_regions"]
	RegionManager._region_definitions = original["definitions"]
	QuestManager._apply_save_data(original["quests"])
	ExamManager._apply_save_data(original["exam"])
	CodexManager._apply_save_data(original["codex"])
	MapManager._clear_reinforcement()
	GameManager.current_state = original["state"]
	get_tree().root.size = original_viewport
	await get_tree().process_frame


func _markers() -> Array:
	return MapManager.get_markers(region, player)


func _marker_for(node: Node) -> Dictionary:
	for marker in _markers():
		if marker["id"] == node.get_instance_id():
			return marker
	return {}


func test_world_atlas_has_all_five_actual_module_mappings_and_no_fake_worlds() -> void:
	var expected := {
		"region_1": "module_2",
		"region_2": "module_3",
		"region_3": "module_4",
		"region_4": "module_5",
		"region_5": "module_1",
	}
	assert_eq(MapManager.get_regions().size(), 5)
	for entry in MapManager.get_regions():
		var info := MapManager.get_region_info(entry["region_id"])
		assert_eq(info["module_id"], expected[entry["region_id"]])
		assert_eq(info["module_title"], CodexManager.get_module(info["module_id"])["module_title"])
	assert_false(MapManager.get_region_info("region_3")["defined"])
	assert_false(MapManager.get_region_info("region_3")["completed"])


func test_selecting_a_locked_region_never_travels_or_unlocks_it() -> void:
	var ui := WORLD_SCENE.instantiate()
	add_child(ui)
	assert_true(ui.open_map())
	ui.select_region("region_2")
	assert_true(ui.information.text.contains("Locked"))
	assert_eq(RegionManager.current_region_id, "region_1")
	assert_false(RegionManager.is_region_unlocked("region_2"))
	ui.select_region("region_5")
	assert_true(ui.information.text.contains("Not yet available"))
	ui.close_button.pressed.emit()
	assert_false(ui.visible)
	assert_false(get_tree().paused)
	assert_true(ui.open_map())
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	ui._input(cancel)
	assert_false(ui.visible)
	ui.free()


func test_world_map_open_requests_reuse_one_screen_and_m_shortcut_opens_it() -> void:
	var ui := WORLD_SCENE.instantiate()
	add_child(ui)
	var main := MAIN_SCRIPT.new()
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	main._unhandled_input(key)
	assert_true(ui.visible)
	EventBus.world_map_open_requested.emit()
	assert_true(ui.visible)
	ui._input(key)
	assert_false(ui.visible)
	assert_false(get_tree().paused)
	main.free()
	ui.free()


func test_passing_the_real_region_exam_updates_atlas_and_completes_region() -> void:
	QuestManager._quest_states["learn_post_harvest_basics"] = {
		"state": "completed", "objectives": {}
	}
	assert_false(MapManager.get_region_info("region_1")["completed"])
	var info := MapManager.get_region_info("region_1")
	assert_eq(info["main_completed"], 1)
	assert_eq(info["main_total"], 1)
	# Use the real exam finish path, preserving its authored threshold/unlock rules.
	ExamManager._current_exam_id = "region1_exam"
	ExamManager._current_questions = [{}, {}]
	ExamManager._current_correct_count = 2
	ExamManager._is_active = true
	ExamManager._finish_exam()
	assert_true(MapManager.get_region_info("region_2")["unlocked"])
	assert_true(MapManager.get_region_info("region_1")["completed"])
	assert_eq(MapManager.get_region_info("region_2")["available"], 1)


func test_unstarted_chained_quest_is_not_reported_as_available() -> void:
	RegionManager._unlocked_regions["region_2"] = true
	assert_eq(MapManager.get_region_info("region_2")["available"], 0)
	assert_eq(MapManager.get_region_info("region_1")["available"], 1)
	QuestManager._quest_states["learn_post_harvest_basics"] = {
		"state": "completed", "objectives": {}
	}
	assert_eq(MapManager.get_region_info("region_2")["available"], 1)


func test_local_player_and_npc_markers_use_actual_world_positions() -> void:
	assert_same(MapManager.get_current_region_root(), region)
	assert_same(MapManager.get_local_player(region), player)
	assert_eq(_marker_for(npc)["position"], npc.global_position)
	assert_eq(_marker_for(npc)["kind"], "npc")
	var projected := NAVIGATION.project_position(
		npc.global_position, player.global_position, Vector2(200, 120), 100
	)
	assert_eq(projected, Vector2(140, 100))
	player.position += Vector2(20, 0)
	assert_ne(
		NAVIGATION.project_position(
			npc.global_position, player.global_position, Vector2(200, 120), 100
		),
		projected
	)


func test_main_quest_guides_fishing_then_turn_in_npc_and_stops_on_completion() -> void:
	assert_eq(_marker_for(spot)["kind"], "fishing")
	QuestManager.start_quest("learn_post_harvest_basics")
	assert_eq(_marker_for(spot)["kind"], "main_quest")
	QuestManager.update_quest_progress("learn_post_harvest_basics", {"objectives_complete": true})
	assert_eq(_marker_for(npc)["kind"], "main_quest")
	assert_eq(_marker_for(spot)["kind"], "fishing")
	QuestManager.complete_quest("learn_post_harvest_basics")
	assert_eq(_marker_for(npc)["kind"], "npc")


func test_wrong_fish_or_disabled_spot_is_not_a_quest_target() -> void:
	QuestManager.start_quest("learn_post_harvest_basics")
	spot.possible_fish_ids = ["golden_tilapia"]
	assert_eq(_marker_for(spot)["kind"], "fishing")
	spot.enabled = false
	assert_true(_marker_for(spot).is_empty())


func test_mini_quest_route_and_fishing_reinforcement_have_distinct_markers() -> void:
	RegionManager.unlock_region("region_2")
	QuestManager.start_quest("visit_region2_mini")
	assert_eq(_marker_for(exit)["kind"], "mini_quest")
	EventBus.mini_quest_question_ready.emit(spot.spot_id, {})
	assert_eq(_marker_for(spot)["kind"], "mini_quest")
	EventBus.fishing_question_ready.emit(spot.spot_id, {})
	assert_eq(_marker_for(spot)["kind"], "fishing")
	QuestManager.update_quest_progress("visit_region2_mini", {"objectives_complete": true})
	assert_eq(_marker_for(exit)["kind"], "exit")


func test_locked_quest_route_guides_to_examiner_before_highlighting_the_exit() -> void:
	var examiner: NPC = load("res://Scene/NPC/npc_examiner_santaigo.tscn").instantiate()
	region.add_child(examiner)
	examiner.position = player.position + Vector2(20, 20)
	QuestManager._quest_states["learn_post_harvest_basics"] = {
		"state": "completed", "objectives": {}
	}
	QuestManager.start_quest("visit_region2_mini")
	assert_eq(_marker_for(examiner)["kind"], "mini_quest")
	assert_eq(_marker_for(exit)["kind"], "exit")
	RegionManager.unlock_region("region_2")
	assert_eq(_marker_for(exit)["kind"], "mini_quest")
	assert_eq(_marker_for(examiner)["kind"], "exam")


func test_other_regions_and_distant_nonquest_pois_do_not_leak_into_mini_map() -> void:
	var other_region := Node2D.new()
	add_child(other_region)
	var other_npc := NPC_SCENE.instantiate()
	other_region.add_child(other_npc)
	other_npc.position = player.position
	for marker in _markers():
		assert_ne(marker["id"], other_npc.get_instance_id())
	npc.position = Vector2(10000, 10000)
	assert_true(_marker_for(npc).is_empty())
	QuestManager.start_quest("learn_post_harvest_basics")
	spot.position = Vector2(10000, 10000)
	assert_eq(_marker_for(spot)["kind"], "main_quest")
	other_region.free()


func test_transition_drops_markers_and_repeated_reads_never_duplicate_them() -> void:
	var count := _markers().size()
	assert_eq(_markers().size(), count)
	SaveManager.is_loading = true
	assert_null(MapManager.get_current_region_root())
	SaveManager.is_loading = false
	container.remove_child(region)
	assert_null(MapManager.get_current_region_root())
	region.free()
	region = REGION_SCENE.instantiate()
	container.add_child(region)
	player = region.get_node("player")
	assert_eq(_markers().size(), 0)


func test_mini_map_tracks_camera_and_hides_for_gameplay_overlays() -> void:
	var mini := MINI_SCENE.instantiate()
	add_child(mini)
	assert_false(
		mini._blocked(),
		(
			"Gameplay state: %s"
			% {
				"paused": get_tree().paused,
				"dialogue": DialogueManager.is_active,
				"fishing": FishingManager.is_fishing(),
				"load": SaveManager.is_loading,
				"scene": SceneLoader.is_loading(),
				"overlay": MapManager.has_blocking_overlay(),
			}
		)
	)
	mini.refresh()
	assert_true(mini.visible)
	assert_eq(mini.map_camera.position, player.global_position)
	player.position += Vector2(100, 0)
	mini.refresh()
	assert_eq(mini.surface.player_position, player.global_position)
	GameManager.set_paused(true)
	assert_false(mini.visible, "Pause hides the mini map synchronously")
	GameManager.set_paused(false)
	mini.refresh()
	assert_true(mini.visible)
	var overlay := Control.new()
	add_child(overlay)
	overlay.add_to_group("gameplay_overlay")
	mini.refresh()
	assert_false(mini.visible)
	overlay.hide()
	mini.refresh()
	assert_true(mini.visible)
	watch_signals(EventBus)
	mini.map_button.pressed.emit()
	assert_signal_emitted(EventBus, "world_map_open_requested")
	overlay.free()
	mini.free()


func test_custom_marker_can_follow_one_actual_quest_objective() -> void:
	var location := LOCATION.new()
	location.title = "Dock objective"
	location.quest_id = "learn_post_harvest_basics"
	location.objective_index = 0
	region.add_child(location)
	location.position = player.position
	assert_true(_marker_for(location).is_empty())
	QuestManager.start_quest("learn_post_harvest_basics")
	assert_eq(_marker_for(location)["kind"], "main_quest")
	QuestManager.update_quest_progress("learn_post_harvest_basics", {"objectives_complete": true})
	assert_true(_marker_for(location).is_empty())


func test_portrait_and_landscape_layouts_keep_close_and_region_buttons_accessible() -> void:
	var ui := WORLD_SCENE.instantiate()
	add_child(ui)
	assert_true(ui.open_map())
	for viewport_size in [Vector2i(390, 844), Vector2i(720, 360)]:
		get_tree().root.size = viewport_size
		for frame in range(5):
			await get_tree().process_frame
		assert_lte(ui.close_button.get_global_rect().end.x, float(viewport_size.x))
		assert_lte(ui.close_button.get_global_rect().end.y, float(viewport_size.y))
		assert_eq(ui.region_buttons.get_child_count(), 5)
		assert_gte(ui.canvas.size.y, 100.0)
	ui.close_map()
	ui.free()


func test_map_rebuilds_from_existing_save_sections_after_scene_restore() -> void:
	SaveManager._registered_sections = []
	SaveManager.register_section(
		"regions", RegionManager._get_save_data, RegionManager._apply_save_data
	)
	SaveManager.register_section(
		"quests", QuestManager._get_save_data, QuestManager._apply_save_data
	)
	save_slot = 1000000000 + randi_range(0, 1000000000)
	while SaveManager.slot_exists(save_slot):
		save_slot += 1
	RegionManager._unlocked_regions["region_2"] = true
	QuestManager.start_quest("learn_post_harvest_basics")
	assert_true(SaveManager.save_game(save_slot))
	var old_player := player
	RegionManager._unlocked_regions = {"region_1": true}
	QuestManager._quest_states = {}
	assert_true(await SaveManager.load_game(save_slot))
	assert_false(is_instance_valid(old_player))
	var restored := MapManager.get_current_region_root()
	assert_not_null(restored)
	assert_not_null(MapManager.get_local_player(restored))
	assert_true(MapManager.get_region_info("region_2")["unlocked"])
	assert_eq(QuestManager.get_quest_state("learn_post_harvest_basics"), "active")
	assert_eq(MapManager.get_markers(restored, MapManager.get_local_player(restored)).size(), 0)


func test_active_objectives_are_prioritized_when_many_points_are_nearby() -> void:
	for index in range(30):
		var marker := LOCATION.new()
		region.add_child(marker)
		marker.position = player.position + Vector2(index, 0)
	QuestManager.start_quest("learn_post_harvest_basics")
	assert_lte(_markers().size(), 12)
	assert_eq(_marker_for(spot)["kind"], "main_quest")


func test_map_cannot_interrupt_inventory_dialogue_fishing_or_foreign_pause() -> void:
	var ui := WORLD_SCENE.instantiate()
	add_child(ui)
	var overlay := Control.new()
	add_child(overlay)
	overlay.add_to_group("gameplay_overlay")
	assert_false(ui.open_map())
	overlay.hide()
	var previous_dialogue := DialogueManager.is_active
	DialogueManager.is_active = true
	assert_false(ui.open_map())
	DialogueManager.is_active = previous_dialogue
	var previous_fishing: int = FishingManager._state
	FishingManager._state = FishingManager.FlowState.CASTING
	assert_false(ui.open_map())
	FishingManager._state = previous_fishing
	get_tree().paused = true
	assert_false(ui.open_map())
	ui.close_map()
	assert_true(get_tree().paused)
	get_tree().paused = false
	ui.free()
	overlay.free()
