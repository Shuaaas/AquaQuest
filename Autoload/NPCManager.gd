extends Node
## NPCManager (Autoload Singleton)
##
## Single responsibility: know which NPCs and dialogue trees exist (loaded
## from JSON), decide which dialogue STATE currently applies to a given
## NPC based on quest progress, and execute the ACTIONS a dialogue node
## triggers (give a quest, reward an item, unlock a region/fishing spot,
## start an exam, open a shop). It does not render any UI and does not
## know how dialogue playback or branching itself works - that is
## DialogueManager's job, which this only calls into.
##
## This is also the ONLY script that interprets what a dialogue "action"
## means. DialogueManager stays fully agnostic of quests/items/regions -
## it just relays whatever action dictionaries a node carries.
##
## DATA LOCATIONS:
##   Data/JSON/NPC/*.json       - one file per NPC: who they are, which
##                                 dialogue tree they use
##   Data/JSON/Dialogue/*.json  - one file per dialogue tree: branching
##                                 states, nodes, conditions, actions
## See README_NPC_SYSTEM.md for the full JSON schema and action reference.

const NPC_JSON_DIR := "res://Data/JSON/NPC/"
const DIALOGUE_JSON_DIR := "res://Data/JSON/Dialogue/"

# npc_id -> npc definition Dictionary
var _npc_definitions: Dictionary = {}
# dialogue_id -> dialogue tree Dictionary (the full parsed JSON file)
var _dialogue_trees: Dictionary = {}

# Tracked only while a conversation is active, so action handlers that need
# to know "who am I talking to" (e.g. open_shop) have something to use.
var _current_npc_node: Node = null
var _current_interactor: Node = null


func _ready() -> void:
	_load_all(NPC_JSON_DIR, _npc_definitions, "npc_id")
	_load_all(DIALOGUE_JSON_DIR, _dialogue_trees, "dialogue_id")
	EventBus.dialogue_action_triggered.connect(_on_dialogue_action_triggered)


func _load_all(dir_path: String, target: Dictionary, key_field: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("NPCManager: directory not found yet: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open(dir_path + file_name, FileAccess.READ)
			if file == null:
				file_name = dir.get_next()
				continue
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has(key_field):
				target[parsed[key_field]] = parsed
			else:
				push_warning("NPCManager: %s missing required field '%s'" % [file_name, key_field])
		file_name = dir.get_next()
	dir.list_dir_end()


## Called by NPC.gd on interact(). Picks whichever dialogue_state's
## condition currently matches quest progress (first match wins - list
## more specific conditions before a fallback "condition": null state,
## which should always be last), then starts it via DialogueManager.
func start_conversation(npc_id: String, interactor: Node, npc_node: Node) -> void:
	if not _npc_definitions.has(npc_id):
		push_error("NPCManager: unknown npc_id '%s'" % npc_id)
		return

	var npc_def: Dictionary = _npc_definitions[npc_id]
	var dialogue_id: String = npc_def.get("dialogue_id", "")
	if not _dialogue_trees.has(dialogue_id):
		push_error("NPCManager: npc '%s' references unknown dialogue_id '%s'" % [npc_id, dialogue_id])
		return

	_current_npc_node = npc_node
	_current_interactor = interactor

	var tree: Dictionary = _dialogue_trees[dialogue_id]
	var states: Array = tree.get("dialogue_states", [])

	for state in states:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		if _condition_matches(state.get("condition", null)):
			DialogueManager.start_dialogue_tree(
				dialogue_id,
				state.get("nodes", {}),
				state.get("start_node", "")
			)
			return

	push_warning("NPCManager: no dialogue_state matched for npc '%s' - add a fallback state with \"condition\": null" % npc_id)


## Condition schema: null (or the key omitted) always matches - use this
## as a fallback state, listed LAST in dialogue_states. Otherwise:
##   {"quest_id": String, "state": String, "objectives_complete": bool}
## where state is one of "not_started", "active", "completed", "failed",
## compared against QuestManager.get_quest_state(). This is the entire
## mechanism behind "dialogue branches based on quest progress."
##
## "objectives_complete" is optional (added for Phase 7 - Quest System).
## When present, it also checks QuestManager.get_quest_progress(quest_id)'s
## "objectives_complete" flag, set by QuestObjectiveManager once every
## objective is satisfied. This is what lets a dialogue state distinguish
## "quest active, still working on it" from "quest active, ready to turn
## in" - both share state == "active", only the flag differs. Conditions
## written before this phase existed simply never set this key, so they're
## unaffected.
func _condition_matches(condition) -> bool:
	if condition == null or typeof(condition) != TYPE_DICTIONARY:
		return true

	var quest_id: String = condition.get("quest_id", "")
	var required_state: String = condition.get("state", "")
	var actual_state := QuestManager.get_quest_state(quest_id)
	if actual_state == "unknown":
		actual_state = "not_started"
	if actual_state != required_state:
		return false

	if condition.has("objectives_complete"):
		var required_flag: bool = condition.get("objectives_complete", false)
		var actual_flag: bool = QuestManager.get_quest_progress(quest_id).get("objectives_complete", false)
		if actual_flag != required_flag:
			return false

	return true


## Reacts to EventBus.dialogue_action_triggered, fired once per action as
## DialogueManager enters each node. See README_NPC_SYSTEM.md for the full
## action type reference table.
func _on_dialogue_action_triggered(action: Dictionary) -> void:
	var action_type: String = action.get("type", "")

	match action_type:
		"start_quest":
			QuestManager.start_quest(action.get("quest_id", ""))
		"complete_quest":
			# UPGRADED for Phase 7 (Quest System): this used to call
			# QuestManager.complete_quest() directly (bare completion, no
			# reward). It now routes through QuestObjectiveManager, which
			# still marks the quest completed but ALSO grants that quest's
			# defined reward and auto-starts next_quest_id if the quest
			# has a Data/JSON/Quests/ definition. If it doesn't, this
			# falls back to the exact old bare-completion behavior - fully
			# backward compatible with any dialogue JSON written before
			# this phase existed.
			QuestObjectiveManager.turn_in_quest(action.get("quest_id", ""))
		"fail_quest":
			QuestManager.fail_quest(action.get("quest_id", ""))
		"update_quest_progress":
			QuestManager.update_quest_progress(action.get("quest_id", ""), action.get("progress", {}))
		"give_item":
			InventoryManager.add_item(action.get("item_id", ""), action.get("amount", 1))
		"unlock_region":
			RegionManager.unlock_region(action.get("region_id", ""))
		"unlock_fishing_spot":
			_unlock_fishing_spot(action.get("spot_id", ""))
		"start_exam":
			# Hook only. A future ExamManager (mirroring FishingManager's
			# design - see FishingManager.gd) should listen for
			# EventBus.exam_started and drive real multi-question exam
			# flow. NPCManager only announces intent; it does not know
			# how to run or grade an exam.
			EventBus.exam_started.emit(action.get("exam_id", ""))
		"open_shop":
			# Hook only. Full buy/sell logic and a shop item catalog are
			# future work for a dedicated Merchant shop UI/system. This
			# just announces that a shop screen should open.
			EventBus.shop_opened.emit(_current_npc_node)
		_:
			push_warning("NPCManager: unknown action type '%s'" % action_type)


func _unlock_fishing_spot(spot_id: String) -> void:
	for spot in get_tree().get_nodes_in_group("fishing_spots"):
		if spot is FishingSpot and spot.spot_id == spot_id:
			spot.enabled = true
			return
	push_warning("NPCManager: no FishingSpot found with spot_id '%s' to unlock" % spot_id)
