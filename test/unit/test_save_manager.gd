extends GutTest


class SaveProvider:
	extends Node
	var value: int = 0
	var applied: bool = false
	var wait_before_apply: bool = false
	var fail_apply: bool = false
	var dependency: Node
	var dependency_was_ready: bool = false

	func get_data() -> Dictionary:
		return {"value": value}

	func apply_data(data: Dictionary) -> bool:
		if wait_before_apply:
			await get_tree().process_frame
		if fail_apply:
			return false
		value = int(data.get("value", 0))
		applied = true
		if dependency != null:
			dependency_was_ready = dependency.applied
		return true


class IsolatedSaveManager:
	extends "res://Autoload/SaveManager.gd"
	var test_path: String

	func _slot_path(_slot: int) -> String:
		return test_path


var manager: IsolatedSaveManager


func before_each() -> void:
	manager = IsolatedSaveManager.new()
	manager.test_path = "user://gut_temp_directory/save_regression_%d.json" % Time.get_ticks_usec()
	add_child_autofree(manager)


func after_each() -> void:
	if FileAccess.file_exists(manager.test_path):
		DirAccess.remove_absolute(manager.test_path)


func test_registering_a_replacement_player_keeps_only_the_latest_callbacks() -> void:
	var old_player := SaveProvider.new()
	var new_player := SaveProvider.new()
	add_child_autofree(old_player)
	add_child_autofree(new_player)
	manager.register_section("player", old_player.get_data, old_player.apply_data)
	manager.register_section("player", new_player.get_data, new_player.apply_data)
	assert_eq(manager._registered_sections.size(), 1)
	assert_eq(manager._registered_sections[0]["get_data"], new_player.get_data)


func test_load_waits_for_region_restoration_before_applying_player_state() -> void:
	var region := SaveProvider.new()
	var player := SaveProvider.new()
	add_child_autofree(region)
	add_child_autofree(player)
	region.wait_before_apply = true
	region.value = 2
	player.value = 42
	player.dependency = region
	manager.register_section("regions", region.get_data, region.apply_data)
	manager.register_section("player", player.get_data, player.apply_data)
	assert_true(manager.save_game())
	region.value = 0
	player.value = 0
	var loaded: bool = await manager.load_game()
	assert_true(loaded)
	assert_true(player.dependency_was_ready)
	assert_eq(region.value, 2)
	assert_eq(player.value, 42)
	# Let an unfinished callback settle even when this regression fails.
	await get_tree().process_frame


func test_departing_player_cannot_unregister_its_replacement() -> void:
	var old_player := SaveProvider.new()
	var new_player := SaveProvider.new()
	add_child_autofree(old_player)
	add_child_autofree(new_player)
	manager.register_section("player", old_player.get_data, old_player.apply_data)
	manager.register_section("player", new_player.get_data, new_player.apply_data)
	manager.unregister_section("player", old_player.get_data)
	assert_eq(manager._registered_sections.size(), 1)
	assert_eq(manager._registered_sections[0]["get_data"], new_player.get_data)
	manager.unregister_section("player", new_player.get_data)
	assert_eq(manager._registered_sections.size(), 0)


func test_player_state_is_applied_last_even_when_registered_first() -> void:
	var region := SaveProvider.new()
	var player := SaveProvider.new()
	add_child_autofree(region)
	add_child_autofree(player)
	region.wait_before_apply = true
	player.dependency = region
	manager.register_section("player", player.get_data, player.apply_data)
	manager.register_section("regions", region.get_data, region.apply_data)
	assert_true(manager.save_game())
	assert_true(await manager.load_game())
	assert_true(player.dependency_was_ready)


func test_incomplete_load_blocks_saving_and_a_second_load() -> void:
	var region := SaveProvider.new()
	add_child_autofree(region)
	region.wait_before_apply = true
	manager.register_section("regions", region.get_data, region.apply_data)
	assert_true(manager.save_game())
	manager.load_game()
	assert_true(manager.is_loading)
	assert_false(manager.save_game())
	assert_false(await manager.load_game())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(manager.is_loading)


func test_invalid_section_data_does_not_change_live_state() -> void:
	var provider := SaveProvider.new()
	add_child_autofree(provider)
	provider.value = 19
	manager.register_section("player", provider.get_data, provider.apply_data)
	var file := FileAccess.open(manager.test_path, FileAccess.WRITE)
	file.store_string('{"sections":{"player":[]}}')
	file.close()
	assert_false(await manager.load_game())
	assert_eq(provider.value, 19)
	assert_false(manager.is_loading)


func test_failed_region_restoration_stops_before_applying_player_state() -> void:
	var region := SaveProvider.new()
	var player := SaveProvider.new()
	add_child_autofree(region)
	add_child_autofree(player)
	region.wait_before_apply = true
	region.fail_apply = true
	manager.register_section("regions", region.get_data, region.apply_data)
	manager.register_section("player", player.get_data, player.apply_data)
	assert_true(manager.save_game())
	watch_signals(EventBus)
	assert_false(await manager.load_game())
	assert_false(player.applied)
	assert_false(manager.is_loading)
	assert_signal_not_emitted(EventBus, "load_completed")


func test_unavailable_provider_does_not_overwrite_an_existing_save() -> void:
	var player := SaveProvider.new()
	add_child(player)
	player.value = 71
	manager.register_section("player", player.get_data, player.apply_data)
	assert_true(manager.save_game())
	var before := FileAccess.get_file_as_string(manager.test_path)
	player.free()
	assert_false(manager.save_game())
	assert_push_error("SaveManager: unavailable save section 'player'")
	assert_eq(FileAccess.get_file_as_string(manager.test_path), before)
