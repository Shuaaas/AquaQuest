extends Node
## Read-only map views of existing progress. Does not unlock, travel, or save.

const MAP_PATH := "res://Data/JSON/Maps/world_map.json"
const NAVIGATION := preload("res://Scripts/Systems/Map/MapNavigation.gd")

var _data: Dictionary = {}
var _navigation := NAVIGATION.new()
var _reinforcement_spot: String = ""


func _ready() -> void:
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary and parsed.get("regions") is Array:
			_data = parsed
	if _data.is_empty():
		push_warning("MapManager: cannot read map metadata at " + MAP_PATH)
	for event in [
		EventBus.region_changed,
		EventBus.region_unlocked,
		EventBus.quest_started,
		EventBus.quest_updated,
		EventBus.quest_completed,
		EventBus.quest_failed,
		EventBus.exam_completed,
		EventBus.load_completed,
		EventBus.game_started,
		EventBus.scene_load_started,
		EventBus.scene_load_finished,
	]:
		event.connect(_on_state_changed)
	EventBus.mini_quest_question_ready.connect(_on_mini_question)
	EventBus.fishing_question_ready.connect(_on_main_question)
	EventBus.fishing_ended.connect(_on_fishing_ended)
	EventBus.load_completed.connect(_clear_reinforcement)
	EventBus.region_changed.connect(_clear_reinforcement)


func get_regions() -> Array:
	return _data.get("regions", []).duplicate(true)


func get_region_info(region_id: String) -> Dictionary:
	var metadata: Dictionary = {}
	for entry in _data.get("regions", []):
		if entry["region_id"] == region_id:
			metadata = entry
	if metadata.is_empty():
		return {}
	var definition := RegionManager.get_region_definition(region_id)
	var module := CodexManager.get_module(metadata["module_id"])
	var unlocked := not definition.is_empty() and RegionManager.is_region_unlocked(region_id)
	var main_total := 0
	var main_completed := 0
	var available := 0
	for quest_id: String in metadata.get("quest_ids", []):
		var quest := QuestObjectiveManager.get_quest_definition(quest_id)
		if quest.is_empty():
			continue
		if quest.get("quest_type", "main") == "main":
			main_total += 1
			if QuestManager.is_quest_completed(quest_id):
				main_completed += 1
		if unlocked and _quest_available(quest_id):
			available += 1
	var exams_passed := true
	var exam_count := 0
	for exam in ExamManager.get_exam_definitions().values():
		if exam.get("region_id", "") == region_id:
			exam_count += 1
			var passed := false
			for attempt in ExamManager.get_exam_history(exam["exam_id"]):
				passed = passed or bool(attempt.get("passed", false))
			exams_passed = exams_passed and passed
	return {
		"region_id": region_id,
		"module_id": metadata["module_id"],
		"name": definition.get("name", region_id.replace("_", " ").capitalize()),
		"description": definition.get("description", "This region is not available yet."),
		"module_title": module.get("module_title", "Module unavailable"),
		"defined": not definition.is_empty(),
		"unlocked": unlocked,
		"current": region_id == RegionManager.current_region_id,
		"main_total": main_total,
		"main_completed": main_completed,
		"available": available,
		"exam_count": exam_count,
		"exams_passed": exam_count > 0 and exams_passed,
		"completed": unlocked and main_total > 0 and main_completed == main_total and exams_passed,
	}


func _quest_available(quest_id: String) -> bool:
	var state := QuestManager.get_quest_state(quest_id)
	if state == "active":
		return true
	if state != "unknown":
		return false
	# A chained quest is not offered before its real predecessor is completed.
	for quest in QuestObjectiveManager.get_quest_definitions().values():
		if quest.get("next_quest_id", "") == quest_id:
			if not QuestManager.is_quest_completed(quest["quest_id"]):
				return false
	return true


func get_current_region_root() -> Node:
	if SceneLoader.is_loading() or SaveManager.is_loading:
		return null
	var container := get_tree().get_first_node_in_group("region_container")
	if container == null or container.get_child_count() != 1:
		return null
	var region := container.get_child(0)
	var definition := RegionManager.get_region_definition(RegionManager.current_region_id)
	if definition.is_empty():
		return null
	if region.scene_file_path != "" and region.scene_file_path != definition.get("scene_path", ""):
		return null
	return region


func get_local_player(region: Node) -> Node2D:
	if region == null:
		return null
	for child in region.find_children("*", "CharacterBody2D", true, false):
		if child is Player and child.is_multiplayer_authority():
			return child
	return null


func get_markers(region: Node, player: Node2D, radius: float = 280.0) -> Array:
	if region == null or player == null or not region.is_ancestor_of(player):
		return []
	return _navigation.collect(region, player.global_position, radius, _data, _reinforcement_spot)


func has_blocking_overlay(except: Control = null) -> bool:
	for screen in get_tree().get_nodes_in_group("gameplay_overlay"):
		if screen != except and screen is Control and screen.is_visible_in_tree():
			return true
	return false


func _on_state_changed(_first: Variant = null, _second: Variant = null) -> void:
	EventBus.map_data_changed.emit()


func _on_mini_question(spot_id: String, _question: Dictionary) -> void:
	_reinforcement_spot = spot_id
	EventBus.map_data_changed.emit()


func _on_main_question(_spot_id: String, _question: Dictionary) -> void:
	_clear_reinforcement()


func _on_fishing_ended(_spot_id: String, _success: bool) -> void:
	_clear_reinforcement()


func _clear_reinforcement(_first: Variant = null, _second: Variant = null) -> void:
	_reinforcement_spot = ""
	EventBus.map_data_changed.emit()
