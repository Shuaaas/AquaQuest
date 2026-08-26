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

# Each entry: { "section_name": String, "get_data": Callable, "apply_data": Callable }
# get_data() -> Dictionary   (called on save)
# apply_data(Dictionary)     (called on load)
var _registered_sections: Array[Dictionary] = []

var current_slot: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Systems call this once in their own _ready() to opt into save/load.
## Example:
##   SaveManager.register_section("inventory", get_save_data, load_save_data)
func register_section(section_name: String, get_data: Callable, apply_data: Callable) -> void:
	_registered_sections.append({
		"section_name": section_name,
		"get_data": get_data,
		"apply_data": apply_data,
	})


func save_game(slot: int = current_slot) -> bool:
	EventBus.save_requested.emit(slot)

	var save_dict := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"sections": {},
	}

	for entry: Dictionary in _registered_sections:
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
	EventBus.load_requested.emit(slot)

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: no save file found at %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save file corrupted or unreadable: %s" % path)
		return false

	var save_dict: Dictionary = parsed
	var sections: Dictionary = save_dict.get("sections", {})

	for entry: Dictionary in _registered_sections:
		var section_name: String = entry["section_name"]
		if sections.has(section_name):
			entry["apply_data"].call(sections[section_name])

	current_slot = slot
	EventBus.load_completed.emit(slot)
	return true


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _slot_path(slot: int) -> String:
	return "%s%s%d%s" % [SAVE_DIR, SAVE_FILE_PREFIX, slot, SAVE_FILE_EXT]
