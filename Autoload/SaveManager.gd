extends Node
## SaveManager (Autoload Singleton)
##
## Owns all read/write of persistent player data. Data is stored as JSON
## under user:// so it works identically on Android, iOS, and Desktop
## (user:// resolves to app-sandboxed storage on Android, no permissions
## needed). Other systems never touch the filesystem directly - they
## register a "save section" callback here, keeping SaveManager decoupled
## from what it's actually saving (Open/Closed Principle: add a new
## section without editing this file's save/load logic).

const SAVE_DIR := "user://saves/"
const SAVE_FILE_PREFIX := "aquaquest_slot_"
const SAVE_FILE_EXT := ".json"
const SAVE_VERSION := 1

var current_slot: int = 0
var is_loading: bool = false

# Each entry: { "section_name": String, "get_data": Callable, "apply_data": Callable }
# get_data() -> Dictionary   (called on save)
# apply_data(Dictionary)     (called on load)
var _registered_sections: Array[Dictionary] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Systems call this once in their own _ready() to opt into save/load.
## Example:
##   SaveManager.register_section("inventory", get_save_data, load_save_data)
## New optional progress sections can opt into apply_when_missing to receive
## an empty dictionary when an older save lacks their section.
func register_section(
	section_name: String, get_data: Callable, apply_data: Callable,
	apply_when_missing: bool = false
) -> void:
	# A newly instanced player replaces the departing player's callbacks.
	for i in range(_registered_sections.size()):
		if _registered_sections[i]["section_name"] == section_name:
			_registered_sections[i] = {
				"section_name": section_name,
				"get_data": get_data,
				"apply_data": apply_data,
				"apply_when_missing": apply_when_missing,
			}
			return
	_registered_sections.append({
		"section_name": section_name,
		"get_data": get_data,
		"apply_data": apply_data,
		"apply_when_missing": apply_when_missing,
	})


func unregister_section(section_name: String, get_data: Callable) -> void:
	# Do not let an old player's cleanup unregister its replacement.
	for i in range(_registered_sections.size() - 1, -1, -1):
		var entry: Dictionary = _registered_sections[i]
		if entry["section_name"] == section_name and entry["get_data"] == get_data:
			_registered_sections.remove_at(i)


func save_game(slot: int = current_slot) -> bool:
	if is_loading or SceneLoader.is_loading():
		return false
	EventBus.save_requested.emit(slot)

	var save_dict := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"sections": {},
	}

	for entry: Dictionary in _registered_sections:
		if not entry["get_data"].is_valid():
			push_error("SaveManager: unavailable save section '%s'" % entry["section_name"])
			return false
		var section_data: Dictionary = entry["get_data"].call()
		save_dict["sections"][entry["section_name"]] = section_data

	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing: %s" % path)
		return false

	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()

	EventBus.save_completed.emit(slot)
	return true


func load_game(slot: int = current_slot) -> bool:
	if is_loading or SceneLoader.is_loading() or get_tree().paused:
		return false
	EventBus.load_requested.emit(slot)
	var save_dict := _read_save_file(slot)
	if save_dict.is_empty():
		return false
	var sections: Dictionary = save_dict.get("sections", {})

	is_loading = true
	# Region restoration can replace the player and its registration. Keep
	# section names, not old Callables, and apply player state only afterward.
	var section_names: Array[String] = []
	for entry: Dictionary in _registered_sections:
		# New optional sections can explicitly reset when loading older saves.
		var should_apply: bool = (
			sections.has(entry["section_name"]) or entry.get("apply_when_missing", false)
		)
		if entry["section_name"] != "player" and should_apply:
			section_names.append(entry["section_name"])
	if sections.has("player"):
		section_names.append("player")

	for section_name in section_names:
		var apply_data := Callable()
		for entry: Dictionary in _registered_sections:
			if entry["section_name"] == section_name:
				apply_data = entry["apply_data"]
				break
		if not apply_data.is_valid():
			is_loading = false
			return false
		var result = await apply_data.call(sections.get(section_name, {}))
		if typeof(result) == TYPE_BOOL and not result:
			is_loading = false
			return false

	current_slot = slot
	is_loading = false
	EventBus.load_completed.emit(slot)
	return true


func _read_save_file(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: no save file found at %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save file corrupted or unreadable: %s" % path)
		return {}
	if typeof(parsed.get("sections", {})) != TYPE_DICTIONARY:
		return {}
	for section_data in parsed.get("sections", {}).values():
		if typeof(section_data) != TYPE_DICTIONARY:
			return {}
	return parsed


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _slot_path(slot: int) -> String:
	return "%s%s%d%s" % [SAVE_DIR, SAVE_FILE_PREFIX, slot, SAVE_FILE_EXT]
