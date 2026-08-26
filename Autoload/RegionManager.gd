extends Node
## RegionManager (Autoload Singleton)
##
## Tracks which fisheries region the player is currently in and which
## regions are unlocked. Region *definitions* (name, unlock requirements,
## scene path, associated quest/exam ids) live in Data/JSON/Regions as
## data, not code - so designers can add a new region without touching
## this script (scalable for future regions, per project rules).

const REGIONS_JSON_DIR := "res://Data/JSON/Regions/"

# region_id -> region definition Dictionary loaded from JSON
var _region_definitions: Dictionary = {}
# region_id -> bool
var _unlocked_regions: Dictionary = {}

var current_region_id: String = ""


func _ready() -> void:
	_load_region_definitions()
	SaveManager.register_section("regions", _get_save_data, _apply_save_data)


func _load_region_definitions() -> void:
	var dir := DirAccess.open(REGIONS_JSON_DIR)
	if dir == null:
		push_warning("RegionManager: no Regions JSON directory found yet at %s" % REGIONS_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path := REGIONS_JSON_DIR + file_name
			var def := _load_json_file(full_path)
			if def.has("region_id"):
				_region_definitions[def["region_id"]] = def
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func unlock_region(region_id: String) -> void:
	if _unlocked_regions.get(region_id, false):
		return
	_unlocked_regions[region_id] = true
	EventBus.region_unlocked.emit(region_id)


func is_region_unlocked(region_id: String) -> bool:
	return _unlocked_regions.get(region_id, false)


func travel_to_region(region_id: String) -> void:
	if not _region_definitions.has(region_id):
		push_error("RegionManager: unknown region_id '%s'" % region_id)
		return
	if not is_region_unlocked(region_id):
		push_warning("RegionManager: region '%s' is locked" % region_id)
		return

	var old_region := current_region_id
	current_region_id = region_id
	EventBus.region_changed.emit(old_region, region_id)

	var scene_path: String = _region_definitions[region_id].get("scene_path", "")
	if scene_path != "":
		SceneLoader.change_scene(scene_path)


func get_region_definition(region_id: String) -> Dictionary:
	return _region_definitions.get(region_id, {})


func _get_save_data() -> Dictionary:
	return {
		"current_region_id": current_region_id,
		"unlocked_regions": _unlocked_regions,
	}


func _apply_save_data(data: Dictionary) -> void:
	current_region_id = data.get("current_region_id", "")
	_unlocked_regions = data.get("unlocked_regions", {})
