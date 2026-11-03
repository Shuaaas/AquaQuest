extends RefCounted
## Read-only quest presentation. Never advances objectives or grants rewards.


static func quest_ids(state: String) -> Array:
	var states: Dictionary = QuestManager._get_save_data().get("quest_states", {})
	var result: Array = states.keys().filter(
		func(id): return QuestManager.get_quest_state(id) == state
	)
	result.sort_custom(
		func(a, b):
			var first := QuestObjectiveManager.get_quest_definition(a)
			var second := QuestObjectiveManager.get_quest_definition(b)
			var a_main: bool = first.get("quest_type", "main") == "main"
			var b_main: bool = second.get("quest_type", "main") == "main"
			if a_main != b_main:
				return a_main
			return str(first.get("title", a)) < str(second.get("title", b))
	)
	return result


static func details(quest_id: String) -> Dictionary:
	var definition := QuestObjectiveManager.get_quest_definition(quest_id)
	var state := QuestManager.get_quest_state(quest_id)
	var progress := QuestManager.get_quest_progress(quest_id)
	var settled: bool = state == "completed" or bool(progress.get("objectives_complete", false))
	var objectives: Array = []
	var total := 0
	var done := 0
	var raw_objectives: Array = definition.get("objectives", [])
	for index in raw_objectives.size():
		var objective: Dictionary = raw_objectives[index]
		var target := QuestObjectiveManager.get_objective_target_count(objective)
		var count := maxi(0, int(progress.get("obj_%d" % index, 0)))
		var complete := settled or count >= target
		var counter := (
			("%d recorded · Done" % count if count > 0 else "Done")
			if settled
			else "%d / %d" % [mini(count, target), target]
		)
		objectives.append(
			{
				"text": objective_text(objective),
				"counter": counter,
				"complete": complete,
				"count": count,
				"target": target
			}
		)
		total += target
		done += target if settled else mini(count, target)
	var metadata := _read_json(MapManager.MAP_PATH)
	var giver: String = definition.get(
		"quest_giver", definition.get("npc_id", metadata.get("quest_givers", {}).get(quest_id, ""))
	)
	var location := "Not specified"
	var region_id: String = definition.get("region_id", "")
	for region in MapManager.get_regions():
		if region_id.is_empty() and quest_id in region.get("quest_ids", []):
			region_id = region["region_id"]
	if not region_id.is_empty():
		location = _region_name(region_id)
	var reward: Dictionary = definition.get("reward", {})
	var reward_text := "No item reward configured"
	if not str(reward.get("item_id", "")).is_empty():
		reward_text = (
			"%s ×%d"
			% [ItemDatabase.get_display_name(reward["item_id"]), int(reward.get("amount", 1))]
		)
	return {
		"id": quest_id,
		"title": definition.get("title", quest_id.replace("_", " ").capitalize()),
		"type": "Mini Quest" if definition.get("quest_type", "main") == "mini" else "Main Quest",
		"state": state,
		"status":
		(
			"Ready to turn in"
			if state == "active" and settled
			else {"active": "In progress", "completed": "Completed", "failed": "Failed"}.get(
				state, "Unavailable"
			)
		),
		"description": definition.get("description", "No description configured."),
		"objectives": objectives,
		"percent": 100.0 * done / total if total > 0 else 0.0,
		"giver": _npc_name(giver),
		"location": location,
		"reward": reward_text
	}


static func objective_text(objective: Dictionary) -> String:
	if not str(objective.get("description", "")).is_empty():
		return objective["description"]
	match objective.get("type", ""):
		"catch_fish":
			return "Catch " + ItemDatabase.get_display_name(objective.get("fish_id", "fish"))
		"visit_location":
			return "Visit " + _region_name(objective.get("region_id", ""))
		"answer_questions":
			return "Answer questions correctly"
		"pass_exam":
			return (
				"Pass "
				+ str(objective.get("exam_id", "regional exam")).replace("_", " ").capitalize()
			)
	return str(objective.get("type", "Objective")).replace("_", " ").capitalize()


static func _region_name(region_id: String) -> String:
	var number := region_id.replace("_", " ").capitalize()
	var name: String = RegionManager.get_region_definition(region_id).get("name", number)
	return "%s (%s)" % [name, number] if name != number else number


static func _npc_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return "Not specified"
	if not npc_id.is_valid_identifier():
		return npc_id
	var definition := _read_json(NPCManager.NPC_JSON_DIR.path_join(npc_id + ".json"))
	return str(definition.get("display_name", npc_id.replace("_", " ").capitalize()))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
