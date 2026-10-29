extends Node
## Static lesson catalog and player unlock progress. Rendering belongs to CodexUI.
## Empty/unknown quest requirements deliberately remain locked.

const INDEX_PATH := "res://Resources/Codex/index.json"

var _modules: Dictionary = {}
var _lessons: Dictionary = {}
var _unlocked: Dictionary = {}
var _quest_lessons: Dictionary = {}
var _diagnostics: Array[String] = []


func _ready() -> void:
	load_catalog()
	SaveManager.register_section("codex", _get_save_data, _apply_save_data, true)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.game_started.connect(_on_game_started)


func load_catalog(index_path: String = INDEX_PATH) -> bool:
	_modules.clear()
	_lessons.clear()
	_quest_lessons.clear()
	_diagnostics.clear()
	var index := _read_json(index_path)
	if not index.get("modules") is Array:
		_problem("%s requires a modules array" % index_path)
		return false
	for entry in index["modules"]:
		if not entry is Dictionary or not _strings_present(entry, ["id", "path"]):
			_problem("Invalid module entry in %s" % index_path)
			continue
		_load_module(entry)
	for lesson_id in _unlocked.keys():
		if not _lessons.has(lesson_id):
			_unlocked.erase(lesson_id)
	_index_requirements()
	_reconcile_completed_quests()
	return not _modules.is_empty()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_problem("Cannot open %s" % path)
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		_problem("%s line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if not parser.data is Dictionary:
		_problem("%s must contain a JSON object" % path)
		return {}
	return parser.data


func _load_module(entry: Dictionary) -> void:
	var data := _read_json(entry["path"])
	if not _strings_present(data, ["module_id", "module_title"]):
		_problem("%s requires module_id and module_title" % entry["path"])
		return
	var module_id: String = data["module_id"]
	if module_id != entry["id"] or _modules.has(module_id):
		_problem("Duplicate or mismatched module ID: %s" % module_id)
		return
	if not data.get("lessons") is Array or not data.get("source") is Dictionary:
		_problem("%s requires lessons and source metadata" % module_id)
		return
	var page_count = data["source"].get("page_count", 0)
	if not (page_count is float or page_count is int) or page_count < 1:
		_problem("%s requires a positive source page_count" % module_id)
		return
	var valid_lessons: Array = []
	for lesson in data["lessons"]:
		if not _valid_lesson(lesson, int(page_count)):
			_problem("Invalid lesson in %s; check IDs, text, arrays and source pages" % module_id)
			continue
		var lesson_id: String = lesson["id"]
		if _lessons.has(lesson_id) or lesson.get("module_id", module_id) != module_id:
			_problem("Duplicate or mismatched lesson ID: %s" % lesson_id)
			continue
		lesson["module_id"] = module_id
		_lessons[lesson_id] = lesson
		valid_lessons.append(lesson)
	data["lessons"] = valid_lessons
	_modules[module_id] = data


# Validation keeps each rejected schema shape explicit.
# gdlint: disable=max-returns
func _valid_lesson(value: Variant, page_count: int) -> bool:
	if not value is Dictionary or not _strings_present(value, ["id", "title", "summary"]):
		return false
	if not value.get("sections") is Array or value["sections"].is_empty():
		return false
	if not _valid_pages(value.get("source_pages"), page_count):
		return false
	if not value.get("unlock_requirement") is Dictionary:
		return false
	var requirement: Dictionary = value["unlock_requirement"]
	if not requirement.get("type") is String or not requirement.get("id") is String:
		return false
	for section in value["sections"]:
		if not section is Dictionary or not _strings_present(section, ["heading", "content"]):
			return false
		if not _valid_pages(section.get("source_pages"), page_count):
			return false
		if not _string_array(section.get("image_ids", [])):
			return false
	return _valid_collections(value, page_count)
# gdlint: enable=max-returns


func _valid_collections(value: Dictionary, page_count: int) -> bool:
	for field in ["key_concepts", "examples", "images", "references", "tables"]:
		if not value.get(field, []) is Array:
			return false
		for item in value.get(field, []):
			if not item is Dictionary:
				return false
			var required: Array = {
				"key_concepts": ["term", "definition"], "examples": ["title", "content"],
				"images": ["id", "path", "caption"], "references": ["text"],
				"tables": ["id", "title"],
			}[field]
			if not _strings_present(item, required):
				return false
			if not _valid_pages(item.get("source_pages"), page_count):
				return false
			if field == "tables" and not _valid_table(item):
				return false
	return true


func _valid_table(table: Dictionary) -> bool:
	if not _string_array(table.get("columns")) or not table.get("rows") is Array:
		return false
	for row in table["rows"]:
		if not _string_array(row) or row.size() != table["columns"].size():
			return false
	return true


func _strings_present(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not data.get(key) is String or data[key].strip_edges().is_empty():
			return false
	return true


func _string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not item is String:
			return false
	return true


func _valid_pages(value: Variant, page_count: int) -> bool:
	if not value is Array or value.is_empty():
		return false
	for page in value:
		if not (page is float or page is int):
			return false
		if page != int(page) or page < 1 or page > page_count:
			return false
	return true


func _index_requirements() -> void:
	var unconfigured := 0
	for lesson_id: String in _lessons:
		var requirement: Dictionary = _lessons[lesson_id]["unlock_requirement"]
		var quest_id: String = requirement["id"]
		if requirement["type"] != "quest":
			_problem("%s uses unsupported unlock type '%s'" % [lesson_id, requirement["type"]])
		elif quest_id.is_empty():
			unconfigured += 1
		elif QuestObjectiveManager.get_quest_definition(quest_id).is_empty():
			_problem("%s references unknown quest '%s'; no new unlocks granted" % [lesson_id, quest_id])
		else:
			if not _quest_lessons.has(quest_id):
				_quest_lessons[quest_id] = []
			_quest_lessons[quest_id].append(lesson_id)
	if unconfigured > 0:
		_problem("%d lessons have no configured quest; no automatic unlocks" % unconfigured)


func _problem(message: String) -> void:
	_diagnostics.append(message)
	push_warning("CodexManager: " + message)


func get_diagnostics() -> Array[String]:
	return _diagnostics.duplicate()


func get_modules() -> Array:
	var result: Array = []
	for data: Dictionary in _modules.values():
		result.append({"module_id": data["module_id"], "module_title": data["module_title"]})
	return result


func get_module(module_id: String) -> Dictionary:
	return _modules.get(module_id, {}).duplicate(true)


func get_lessons(module_id: String) -> Array:
	return _modules.get(module_id, {}).get("lessons", []).duplicate(true)


func get_lesson(lesson_id: String) -> Dictionary:
	return _lessons.get(lesson_id, {}).duplicate(true)


func is_lesson_unlocked(lesson_id: String) -> bool:
	return _lessons.has(lesson_id) and _unlocked.has(lesson_id)


func get_lock_message(lesson_id: String) -> String:
	if not _lessons.has(lesson_id):
		return "This lesson is unavailable."
	var requirement: Dictionary = _lessons[lesson_id]["unlock_requirement"]
	if requirement["type"] != "quest" or requirement["id"].is_empty():
		return "Locked: this lesson is not available for review yet."
	var quest := QuestObjectiveManager.get_quest_definition(requirement["id"])
	if quest.is_empty():
		return "Locked: this lesson's required quest is unavailable."
	return "Locked: complete %s to review this lesson." % quest.get("title", requirement["id"])


func _on_quest_completed(quest_id: String) -> void:
	# Validate state as well as the signal: objectives_complete is not a turn-in.
	if not QuestManager.is_quest_completed(quest_id):
		return
	for lesson_id: String in _quest_lessons.get(quest_id, []):
		if not _unlocked.has(lesson_id):
			_unlocked[lesson_id] = true
			EventBus.codex_lesson_unlocked.emit(lesson_id)
			EventBus.codex_progress_changed.emit()


func _reconcile_completed_quests() -> void:
	for quest_id: String in _quest_lessons:
		_on_quest_completed(quest_id)


func _on_load_completed(_slot: int) -> void:
	_reconcile_completed_quests()
	EventBus.codex_progress_changed.emit()


func _on_game_started() -> void:
	_unlocked.clear()
	EventBus.codex_progress_changed.emit()


func _get_save_data() -> Dictionary:
	return {"unlocked_lesson_ids": _unlocked.keys()}


func _apply_save_data(data: Dictionary) -> bool:
	var ids = data.get("unlocked_lesson_ids", [])
	if not _string_array(ids):
		_problem("Saved unlocked_lesson_ids must be an array of strings")
		return false
	_unlocked.clear()
	for lesson_id: String in ids:
		if _lessons.has(lesson_id):
			_unlocked[lesson_id] = true
		else:
			_problem("Ignoring unknown saved lesson '%s'" % lesson_id)
	EventBus.codex_progress_changed.emit()
	return true
