extends GutTest

const REGION_SCENE := preload("res://test/fixtures/save_region.tscn")
const SAVED_REGION := "gut_saved_region"
const OTHER_REGION := "gut_other_region"

var container: Node2D
var slot: int
var original_sections: Array[Dictionary]
var original_definitions: Dictionary
var original_regions: Dictionary
var original_spawn_id: String
var original_slot: int


func before_each() -> void:
	original_sections = SaveManager._registered_sections.duplicate()
	original_definitions = RegionManager._region_definitions.duplicate(true)
	original_regions = RegionManager._get_save_data().duplicate(true)
	original_spawn_id = RegionManager.pending_spawn_id
	original_slot = SaveManager.current_slot
	SaveManager._registered_sections = []
	SaveManager.register_section(
		"regions", RegionManager._get_save_data, RegionManager._apply_save_data
	)
	RegionManager._region_definitions[SAVED_REGION] = {"scene_path": REGION_SCENE.resource_path}
	RegionManager._region_definitions[OTHER_REGION] = {"scene_path": REGION_SCENE.resource_path}
	RegionManager.current_region_id = SAVED_REGION
	RegionManager._unlocked_regions = {SAVED_REGION: true, OTHER_REGION: true}
	RegionManager.pending_spawn_id = "default"
	container = Node2D.new()
	add_child(container)
	container.add_to_group("region_container")
	container.add_child(REGION_SCENE.instantiate())
	slot = 1000000000 + randi_range(0, 1000000000)
	while SaveManager.slot_exists(slot):
		slot += 1


func after_each() -> void:
	container.free()
	SaveManager._registered_sections = original_sections
	SaveManager.current_slot = original_slot
	RegionManager._region_definitions = original_definitions
	RegionManager.current_region_id = original_regions["current_region_id"]
	RegionManager._unlocked_regions = original_regions["unlocked_regions"]
	RegionManager.pending_spawn_id = original_spawn_id
	var path := SaveManager._slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _player() -> Player:
	return container.get_child(0).get_node("player") as Player


func test_cross_region_load_restores_the_scene_position_and_equipment() -> void:
	var old_player := _player()
	old_player.global_position = Vector2(123, 234)
	old_player.fishing_rod.apply_save_state({"rod_equipped": true})
	assert_true(SaveManager.save_game(slot))
	RegionManager.current_region_id = OTHER_REGION
	old_player.global_position = Vector2(-10, -20)
	old_player.fishing_rod.apply_save_state({"rod_equipped": false})
	watch_signals(EventBus)
	assert_true(await SaveManager.load_game(slot))
	assert_false(is_instance_valid(old_player))
	assert_eq(RegionManager.current_region_id, SAVED_REGION)
	assert_eq(container.get_child(0).scene_file_path, REGION_SCENE.resource_path)
	assert_eq(_player().global_position, Vector2(123, 234))
	assert_true(_player().fishing_rod.is_equipped())
	assert_signal_not_emitted(EventBus, "region_changed")
	assert_signal_emitted(EventBus, "load_completed")
	assert_false(SaveManager.is_loading)


func test_repeated_loads_keep_one_live_player_registration() -> void:
	_player().global_position = Vector2(321, 432)
	assert_true(SaveManager.save_game(slot))
	for _iteration in range(3):
		assert_true(await SaveManager.load_game(slot))
		assert_eq(_player().global_position, Vector2(321, 432))
		assert_eq(SaveManager._registered_sections.size(), 2)
		assert_true(SaveManager.save_game(slot))


func test_player_leaving_the_tree_unregisters_its_save_callbacks() -> void:
	container.get_child(0).free()
	assert_eq(SaveManager._registered_sections.size(), 1)
	assert_eq(SaveManager._registered_sections[0]["section_name"], "regions")


func test_unknown_saved_region_does_not_replace_the_current_world() -> void:
	var old_player := _player()
	var file := FileAccess.open(SaveManager._slot_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify({"sections": {
		"regions": {"current_region_id": "missing_region", "unlocked_regions": {}},
		"player": {"position_x": 999, "position_y": 999},
	}}))
	file.close()
	watch_signals(EventBus)
	assert_false(await SaveManager.load_game(slot))
	assert_same(_player(), old_player)
	assert_eq(RegionManager.current_region_id, SAVED_REGION)
	assert_signal_not_emitted(EventBus, "load_completed")
	assert_false(SaveManager.is_loading)
