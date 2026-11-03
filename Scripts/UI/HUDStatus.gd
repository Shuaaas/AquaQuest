extends RefCounted
## Read-only adapter: HUD text always uses actual equipment, points and quest rules.


static func snapshot() -> Dictionary:
	var region := MapManager.get_current_region_root()
	var player := MapManager.get_local_player(region)
	var equipment_id := ""
	if player != null and player.fishing_rod != null:
		equipment_id = player.fishing_rod.get_equipped_rod_id()
	var definition := RegionManager.get_region_definition(RegionManager.current_region_id)
	return {
		"has_player": player != null,
		"equipment_id": equipment_id,
		"equipment_name":
		(
			ItemDatabase.get_display_name(equipment_id)
			if not equipment_id.is_empty()
			else "No equipment"
		),
		"points": FishingManager.get_points(),
		"region": definition.get("name", "AquaQuest"),
		"quest": current_quest(),
	}


static func current_quest() -> Dictionary:
	var definitions := QuestObjectiveManager.get_quest_definitions()
	var ids: Array = definitions.keys().filter(
		func(id): return QuestManager.get_quest_state(id) == "active"
	)
	ids.sort_custom(
		func(a, b):
			var a_main: bool = definitions[a].get("quest_type", "main") == "main"
			var b_main: bool = definitions[b].get("quest_type", "main") == "main"
			return a_main if a_main != b_main else str(a) < str(b)
	)
	if ids.is_empty():
		return {
			"id": "", "title": "No active quest", "text": "Talk to an NPC to begin.", "ready": false
		}
	var id: String = ids[0]
	var definition: Dictionary = definitions[id]
	var progress := QuestManager.get_quest_progress(id)
	if progress.get("objectives_complete", false):
		return {
			"id": id,
			"title": definition.get("title", id),
			"text": "Ready to turn in. Return to the quest giver.",
			"ready": true
		}
	var lines := PackedStringArray()
	for entry in QuestObjectiveManager.get_pending_objectives(id):
		var objective: Dictionary = entry.objective
		var target := QuestObjectiveManager.get_objective_target_count(objective)
		var count := clampi(int(progress.get("obj_%d" % int(entry.index), 0)), 0, target)
		var text: String = definition.get("description", "Quest in progress")
		match objective.get("type", ""):
			"catch_fish":
				text = "Catch " + ItemDatabase.get_display_name(objective.get("fish_id", "fish"))
			"visit_location":
				text = (
					"Visit "
					+ str(
						RegionManager.get_region_definition(objective.get("region_id", "")).get(
							"name", "the destination"
						)
					)
				)
			"answer_questions":
				text = "Answer questions"
			"pass_exam":
				text = "Pass the regional exam"
		lines.append("%s (%d/%d)" % [text, count, target])
	return {
		"id": id, "title": definition.get("title", id), "text": "\n".join(lines), "ready": false
	}
