extends Node
## QuestManager (Autoload Singleton)
##
## Tracks active/completed quest state. Quest *definitions* (objectives,
## rewards, prerequisite region/quest) are data - designed to live as
## Resource files (.tres) under Resources/Quests/ or JSON under
## Data/JSON/Quests, loaded on demand rather than hardcoded here. This
## script only tracks runtime progress and emits signals; it never
## contains quest-specific gameplay logic (that belongs in per-quest
## Resource scripts, keeping QuestManager generic and scalable).

# quest_id -> progress Dictionary, e.g. { "state": "active", "objectives": {...} }
var _quest_states: Dictionary = {}


func _ready() -> void:
	SaveManager.register_section("quests", _get_save_data, _apply_save_data)


func start_quest(quest_id: String) -> void:
	if _quest_states.has(quest_id):
		push_warning("QuestManager: quest '%s' already tracked" % quest_id)
		return
	_quest_states[quest_id] = {"state": "active", "objectives": {}}
	EventBus.quest_started.emit(quest_id)


func update_quest_progress(quest_id: String, progress: Dictionary) -> void:
	if not _quest_states.has(quest_id):
		push_error("QuestManager: cannot update untracked quest '%s'" % quest_id)
		return
	_quest_states[quest_id]["objectives"] = progress
	EventBus.quest_updated.emit(quest_id, progress)


func complete_quest(quest_id: String) -> void:
	if not _quest_states.has(quest_id):
		return
	_quest_states[quest_id]["state"] = "completed"
	EventBus.quest_completed.emit(quest_id)


func fail_quest(quest_id: String) -> void:
	if not _quest_states.has(quest_id):
		return
	_quest_states[quest_id]["state"] = "failed"
	EventBus.quest_failed.emit(quest_id)


func get_quest_state(quest_id: String) -> String:
	return _quest_states.get(quest_id, {}).get("state", "unknown")


## Added for Phase 7 (Quest System) - QuestObjectiveManager reads this to
## know how far along an active quest's objectives are, and NPCManager
## reads it to check the "objectives_complete" flag for dialogue
## conditions. QuestManager itself still doesn't interpret what any of
## this data MEANS - it's just returning whatever was last stored via
## update_quest_progress().
func get_quest_progress(quest_id: String) -> Dictionary:
	return _quest_states.get(quest_id, {}).get("objectives", {})


func is_quest_completed(quest_id: String) -> bool:
	return get_quest_state(quest_id) == "completed"


func _get_save_data() -> Dictionary:
	return {"quest_states": _quest_states}


func _apply_save_data(data: Dictionary) -> void:
	_quest_states = data.get("quest_states", {})
