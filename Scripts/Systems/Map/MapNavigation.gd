extends RefCounted
## Stateless queries of nodes in ONE live region. No cached Node references.

const LOCATION_SCRIPT := preload("res://Scripts/Systems/Map/MapLocation.gd")
const MAX_MARKERS := 12


func collect(
	region: Node,
	player_position: Vector2,
	radius: float,
	metadata: Dictionary,
	reinforcement_spot: String = ""
) -> Array:
	var nodes := region.find_children("*", "Node2D", true, false)
	var candidates: Dictionary = {}
	for node in nodes:
		_add_base_marker(candidates, node)
	for quest_id: String in QuestObjectiveManager.get_quest_definitions():
		if QuestManager.get_quest_state(quest_id) != "active":
			continue
		var quest := QuestObjectiveManager.get_quest_definition(quest_id)
		var kind := "mini_quest" if quest.get("quest_type", "main") == "mini" else "main_quest"
		var pending := QuestObjectiveManager.get_pending_objectives(quest_id)
		if QuestManager.get_quest_progress(quest_id).get("objectives_complete", false):
			var giver: String = metadata.get("quest_givers", {}).get(quest_id, "")
			for node in nodes:
				if node is NPC and giver != "" and node.npc_id == giver and node.enabled:
					_put(candidates, node, kind, "Return to " + node.name, 0)
		else:
			for objective in pending:
				_mark_objective(candidates, nodes, quest_id, kind, objective["objective"], metadata)
	for node in nodes:
		if node.get_script() == LOCATION_SCRIPT:
			_mark_custom(candidates, node)
		if node is FishingSpot and reinforcement_spot != "" and node.spot_id == reinforcement_spot:
			_put(candidates, node, "mini_quest", "Reinforce the current fishing concept", 0)
	var result: Array = []
	for marker: Dictionary in candidates.values():
		marker["distance"] = player_position.distance_to(marker["position"])
		if marker["priority"] == 0 or marker["distance"] <= radius:
			result.append(marker)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["priority"] != b["priority"]:
				return a["priority"] < b["priority"]
			return a["distance"] < b["distance"]
	)
	return result.slice(0, MAX_MARKERS)


func _add_base_marker(candidates: Dictionary, node: Node2D) -> void:
	if node is NPC and node.enabled:
		var kind: String = {"merchant": "shop", "examiner": "exam"}.get(node.npc_type, "npc")
		_put(candidates, node, kind, node.npc_id.replace("_", " ").capitalize(), 2)
	elif node is FishingSpot and node.enabled:
		_put(candidates, node, "fishing", "Fishing spot", 3)
	elif node is RegionExit:
		_put(candidates, node, "exit", "Path to " + node.destination_region_id.replace("_", " "), 2)
	elif node.get_script() == LOCATION_SCRIPT and node.quest_id == "":
		_put(candidates, node, node.marker_kind, node.title, 2)


func _mark_objective(
	candidates: Dictionary,
	nodes: Array,
	quest_id: String,
	kind: String,
	objective: Dictionary,
	metadata: Dictionary
) -> void:
	# A visit goal behind an exam gate points at the real examiner first.
	if objective.get("type", "") == "visit_location":
		var destination: String = objective.get("region_id", "")
		if not RegionManager.is_region_unlocked(destination):
			for exam in ExamManager.get_exam_definitions().values():
				if exam.get("next_region_id", "") == destination:
					_mark_objective(
						candidates,
						nodes,
						quest_id,
						kind,
						{"type": "pass_exam", "exam_id": exam["exam_id"]},
						metadata
					)
			return
	for node in nodes:
		match objective.get("type", ""):
			"catch_fish", "answer_questions":
				if node is FishingSpot and _spot_matches(node, quest_id, objective):
					_put(candidates, node, kind, "Quest fishing location", 0)
			"visit_location":
				if (
					node is RegionExit
					and node.destination_region_id == objective.get("region_id", "")
				):
					_put(candidates, node, kind, "Quest route", 0)
			"pass_exam":
				var npc_id: String = metadata.get("exam_npcs", {}).get(
					objective.get("exam_id", ""), ""
				)
				if node is NPC and node.enabled and npc_id != "" and node.npc_id == npc_id:
					_put(candidates, node, kind, "Quest examination", 0)


func _spot_matches(spot: FishingSpot, quest_id: String, objective: Dictionary) -> bool:
	if not spot.enabled or (spot.required_quest_id != "" and spot.required_quest_id != quest_id):
		return false
	if objective.get("type", "") == "answer_questions":
		return true
	var fish_id: String = objective.get("fish_id", "")
	if not spot.possible_fish_ids.is_empty():
		return spot.possible_fish_ids.has(fish_id)
	var species: Array = FishingAreaManager.get_location(spot.location_id).get("fish_species", [])
	if species.is_empty():
		return fish_id == FishingManager.PLACEHOLDER_FISH_ITEM_ID
	for item in species:
		if item.get("fish_id", "") == fish_id and item.get("weight", 0) > 0:
			return true
	return false


func _mark_custom(candidates: Dictionary, node: Node2D) -> void:
	if node.quest_id == "" or QuestManager.get_quest_state(node.quest_id) != "active":
		return
	var pending := QuestObjectiveManager.get_pending_objectives(node.quest_id)
	for objective in pending:
		if node.objective_index < 0 or objective["index"] == node.objective_index:
			var quest := QuestObjectiveManager.get_quest_definition(node.quest_id)
			var kind := "mini_quest" if quest.get("quest_type", "main") == "mini" else "main_quest"
			_put(candidates, node, kind, node.title, 0)
			return


func _put(candidates: Dictionary, node: Node2D, kind: String, title: String, priority: int) -> void:
	var key := node.get_instance_id()
	if candidates.has(key) and candidates[key]["priority"] < priority:
		return
	candidates[key] = {
		"id": key,
		"position": node.global_position,
		"kind": kind,
		"title": title,
		"priority": priority,
	}


static func project_position(
	world_position: Vector2, player_position: Vector2, map_size: Vector2, radius: float
) -> Vector2:
	return map_size * 0.5 + (world_position - player_position) * map_size.x / (radius * 2.0)
