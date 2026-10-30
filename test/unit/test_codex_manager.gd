extends GutTest

const CODEX_SCRIPT := preload("res://Autoload/CodexManager.gd")
const QUEST_ID := "learn_post_harvest_basics"

class IsolatedSaveManager:
	extends "res://Autoload/SaveManager.gd"
	var test_path: String

	func _slot_path(_slot: int) -> String:
		return test_path


var manager: Node
var original_quests: Dictionary
var original_regions: Dictionary
var original_region_definitions: Dictionary
var original_codex: Dictionary
var files: Array[String] = []
var prefix: String


func before_each() -> void:
	original_quests = QuestManager._quest_states.duplicate(true)
	original_regions = RegionManager._unlocked_regions.duplicate()
	original_region_definitions = RegionManager._region_definitions.duplicate(true)
	original_codex = CodexManager._get_save_data().duplicate(true)
	RegionManager._unlocked_regions = {}
	QuestManager._quest_states = {}
	manager = autofree(CODEX_SCRIPT.new())
	EventBus.quest_completed.connect(manager._on_quest_completed)
	EventBus.region_unlocked.connect(manager._on_region_unlocked)
	EventBus.load_completed.connect(manager._on_load_completed)
	prefix = "user://gut_temp_directory/codex_%d_" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute("user://gut_temp_directory")


func after_each() -> void:
	QuestManager._quest_states = original_quests
	RegionManager._unlocked_regions = original_regions
	RegionManager._region_definitions = original_region_definitions
	CodexManager._apply_save_data(original_codex)
	for path in files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	files.clear()


func _write(name: String, value: Variant) -> String:
	var path := prefix + name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
	files.append(path)
	return path


func _module() -> Dictionary:
	var data := CodexManager.get_module("module_1")
	data["lessons"] = data["lessons"].slice(0, 2)
	for lesson in data["lessons"]:
		lesson["unlock_requirement"] = {"type": "quest", "id": ""}
	data["lessons"][0]["unlock_requirement"]["id"] = QUEST_ID
	return data


func _load_fixture(data: Dictionary) -> bool:
	var module_path := _write("module", data)
	var index_path := _write("index", {"modules": [{"id": "module_1", "path": module_path}]})
	var loaded: bool = manager.load_catalog(index_path)
	assert_engine_error("1 lessons have no configured requirement")
	return loaded


func _load_real_catalog() -> void:
	assert_true(manager.load_catalog())
	for region_id in ["region_3", "region_4", "region_5"]:
		assert_engine_error("Region '%s' is not defined yet" % region_id)


func test_real_catalog_loads_all_five_modules_and_twenty_four_lessons() -> void:
	_load_real_catalog()
	assert_eq(manager.get_modules().size(), 5)
	var total := 0
	for module in manager.get_modules():
		total += manager.get_lessons(module["module_id"]).size()
	assert_eq(total, 24)
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_true(manager.get_lock_message("module_1_lesson_1").contains("Region 5"))
	var copy: Dictionary = manager.get_lesson("module_1_lesson_1")
	copy["title"] = "Mutated copy"
	assert_ne(manager.get_lesson("module_1_lesson_1")["title"], copy["title"])


func test_only_a_real_completed_configured_quest_unlocks_and_emits_once() -> void:
	assert_true(_load_fixture(_module()))
	watch_signals(EventBus)
	EventBus.quest_completed.emit(QUEST_ID)
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))
	QuestManager.start_quest(QUEST_ID)
	EventBus.quest_objectives_completed.emit(QUEST_ID)
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))
	QuestManager.complete_quest(QUEST_ID)
	assert_true(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_false(manager.is_lesson_unlocked("module_1_lesson_2"))
	QuestManager.complete_quest(QUEST_ID)
	assert_signal_emit_count(EventBus, "codex_lesson_unlocked", 1)


func test_unknown_quests_remain_locked_even_if_quest_state_is_completed() -> void:
	var data := _module()
	data["lessons"][0]["unlock_requirement"]["id"] = "codex_nonexistent_quest"
	assert_true(_load_fixture(data))
	assert_engine_error("references unknown quest")
	QuestManager.start_quest("codex_nonexistent_quest")
	QuestManager.complete_quest("codex_nonexistent_quest")
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_true(" ".join(manager.get_diagnostics()).contains("unknown quest"))


func test_missing_and_malformed_files_fail_without_script_errors() -> void:
	assert_false(manager.load_catalog(prefix + "missing.json"))
	assert_engine_error("Cannot open")
	assert_engine_error(prefix + "missing.json requires a modules array")
	assert_true(" ".join(manager.get_diagnostics()).contains("Cannot open"))
	var path := _write("malformed", {})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ not valid JSON")
	file.close()
	assert_false(manager.load_catalog(path))
	assert_engine_error("line 0")
	assert_engine_error(path + " requires a modules array")
	assert_true(" ".join(manager.get_diagnostics()).contains("line"))


func test_duplicate_ids_and_missing_fields_do_not_replace_valid_lessons() -> void:
	var data := _module()
	data["lessons"].append(data["lessons"][0].duplicate(true))
	data["lessons"].append({"id": "incomplete_lesson"})
	assert_true(_load_fixture(data))
	assert_engine_error("Duplicate or mismatched lesson ID")
	assert_engine_error("Invalid lesson in module_1")
	assert_eq(manager.get_lessons("module_1").size(), 2)
	var messages := " ".join(manager.get_diagnostics())
	assert_true(messages.contains("Duplicate"))
	assert_true(messages.contains("Invalid lesson"))


func test_bad_module_does_not_block_other_valid_modules() -> void:
	var valid_path := _write("good_module", _module())
	var index_path := _write("mixed_index", {"modules": [
		{"id": "missing_module", "path": prefix + "missing.json"},
		{"id": "module_1", "path": valid_path},
		{"id": "module_1", "path": valid_path},
	]})
	assert_true(manager.load_catalog(index_path))
	assert_engine_error("Cannot open")
	assert_engine_error("requires module_id and module_title")
	assert_engine_error("Duplicate or mismatched module ID")
	assert_engine_error("1 lessons have no configured requirement")
	assert_eq(manager.get_modules().size(), 1)
	assert_eq(manager.get_lessons("module_1").size(), 2)


func test_missing_pdf_or_image_does_not_discard_a_text_lesson() -> void:
	var data := _module()
	data["source"]["path"] = "res://docs/modules/not_supplied.pdf"
	data["lessons"][0]["images"] = [{
		"id": "test_missing_image", "path": "res://Assets/Codex/not_supplied.png",
		"caption": "Missing source illustration", "source_pages": [3],
	}]
	assert_true(_load_fixture(data))
	assert_eq(manager.get_lessons("module_1").size(), 2)
	assert_false(manager.get_lesson("module_1_lesson_1")["sections"].is_empty())


func test_wrong_nested_field_types_are_reported_and_skipped() -> void:
	var data := _module()
	data["lessons"][0]["images"] = "not_an_array"
	assert_true(_load_fixture(data))
	assert_engine_error("Invalid lesson in module_1")
	assert_eq(manager.get_lessons("module_1").size(), 1)


func test_save_round_trip_and_older_save_without_codex_do_not_leak_unlocks() -> void:
	assert_true(_load_fixture(_module()))
	var save := IsolatedSaveManager.new()
	save.test_path = _write("save", {})
	add_child_autofree(save)
	save.register_section("quests", QuestManager._get_save_data, QuestManager._apply_save_data)
	save.register_section("codex", manager._get_save_data, manager._apply_save_data, true)
	QuestManager.start_quest(QUEST_ID)
	QuestManager.complete_quest(QUEST_ID)
	assert_true(save.save_game())
	assert_true(manager._apply_save_data({}))
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_true(await save.load_game())
	assert_true(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_eq(manager._get_save_data().keys(), ["unlocked_lesson_ids"])
	# A save from before Codex existed must not inherit unlocks from another slot.
	var file := FileAccess.open(save.test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"sections": {"quests": {"quest_states": {}}}}))
	file.close()
	assert_true(await save.load_game())
	assert_false(manager.is_lesson_unlocked("module_1_lesson_1"))


func test_legacy_save_backfills_only_lessons_from_completed_configured_quests() -> void:
	assert_true(_load_fixture(_module()))
	var save := IsolatedSaveManager.new()
	save.test_path = _write("legacy", {"sections": {"quests": {"quest_states": {
		QUEST_ID: {"state": "completed", "objectives": {}},
	}}}})
	add_child_autofree(save)
	save.register_section("quests", QuestManager._get_save_data, QuestManager._apply_save_data)
	save.register_section("codex", manager._get_save_data, manager._apply_save_data, true)
	assert_true(await save.load_game())
	assert_true(manager.is_lesson_unlocked("module_1_lesson_1"))
	assert_false(manager.is_lesson_unlocked("module_1_lesson_2"))


func test_unknown_saved_ids_are_filtered_and_invalid_save_data_is_rejected() -> void:
	assert_true(_load_fixture(_module()))
	assert_true(manager._apply_save_data({"unlocked_lesson_ids": [
		"module_1_lesson_1", "removed_lesson", "module_1_lesson_1",
	]}))
	assert_engine_error("Ignoring unknown saved lesson")
	assert_eq(manager._get_save_data()["unlocked_lesson_ids"], ["module_1_lesson_1"])
	assert_false(manager._apply_save_data({"unlocked_lesson_ids": "not_an_array"}))
	assert_engine_error("Saved unlocked_lesson_ids must be an array")
	assert_true(manager.is_lesson_unlocked("module_1_lesson_1"))


func test_autoload_is_registered_with_save_and_progression_events() -> void:
	assert_true(EventBus.quest_completed.is_connected(CodexManager._on_quest_completed))
	assert_true(EventBus.load_completed.is_connected(CodexManager._on_load_completed))
	assert_true(EventBus.region_unlocked.is_connected(CodexManager._on_region_unlocked))
	var registered := false
	for section in SaveManager._registered_sections:
		if section["section_name"] == "codex":
			registered = section["apply_when_missing"]
	assert_true(registered)


func test_region_one_unlocks_only_module_two_and_repeated_events_are_idempotent() -> void:
	_load_real_catalog()
	watch_signals(EventBus)
	EventBus.region_unlocked.emit("region_1")
	assert_false(manager.is_lesson_unlocked("module_2_lesson_1"))
	RegionManager.unlock_region("region_1")
	for lesson in manager.get_lessons("module_2"):
		assert_true(manager.is_lesson_unlocked(lesson["id"]))
	for module_id in ["module_1", "module_3", "module_4", "module_5"]:
		for lesson in manager.get_lessons(module_id):
			assert_false(manager.is_lesson_unlocked(lesson["id"]))
	var saved: Dictionary = manager._get_save_data().duplicate(true)
	EventBus.region_unlocked.emit("region_1")
	assert_eq(manager._get_save_data(), saved)


func test_region_two_unlocks_module_three_and_preserves_module_two_for_review() -> void:
	_load_real_catalog()
	RegionManager.unlock_region("region_1")
	RegionManager.unlock_region("region_2")
	for module_id in ["module_2", "module_3"]:
		for lesson in manager.get_lessons(module_id):
			assert_true(manager.is_lesson_unlocked(lesson["id"]))
	assert_false(manager.is_lesson_unlocked("module_4_lesson_1"))


func test_region_progress_backfills_catalog_and_older_codex_saves() -> void:
	RegionManager._unlocked_regions = {"region_1": true}
	_load_real_catalog()
	assert_true(manager.is_lesson_unlocked("module_2_lesson_1"))
	assert_true(manager._apply_save_data({}))
	manager._on_load_completed(0)
	assert_eq(manager._get_save_data()["unlocked_lesson_ids"].size(), 4)
	assert_true(manager.is_lesson_unlocked("module_2_lesson_1"))
	RegionManager._unlocked_regions = {}
	assert_true(manager._apply_save_data({}))
	manager._on_load_completed(1)
	assert_false(manager.is_lesson_unlocked("module_2_lesson_1"))


func test_future_region_mappings_wait_for_definitions_and_actual_region_unlocks() -> void:
	_load_real_catalog()
	var mapping := {"region_3": "module_4", "region_4": "module_5", "region_5": "module_1"}
	for region_id: String in mapping:
		RegionManager.unlock_region(region_id)
		var module_id: String = mapping[region_id]
		assert_false(manager.is_lesson_unlocked(module_id + "_lesson_1"))
		# Test-only definition: no production region or scene is created.
		RegionManager._region_definitions[region_id] = {"region_id": region_id}
		manager._on_load_completed(0)
		for lesson in manager.get_lessons(module_id):
			assert_true(manager.is_lesson_unlocked(lesson["id"]))
