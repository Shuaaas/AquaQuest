extends Node
## QuestObjectiveManager (Autoload Singleton)
##
## Single responsibility: know what a quest's objectives actually REQUIRE
## (loaded from JSON), listen to gameplay events to track progress toward
## them automatically, and handle turning a quest in - granting its
## reward and chaining to the next quest. QuestManager itself still only
## tracks raw state/progress data and knows nothing about what any of it
## means (see QuestManager.gd's own doc comment, unchanged) - this script
## is the one that interprets it, the same split used between
## DialogueManager (traversal) and NPCManager (meaning).
##
## KEY DESIGN POINT: every event this listens to already existed before
## this phase - EventBus.item_added (from InventoryManager.add_item(),
## already called by FishingManager on a catch), EventBus.region_changed
## (from RegionManager.travel_to_region()), EventBus.question_answered
## (from FishingManager on every graded answer), and EventBus.exam_completed
## (declared since the original framework, still unemitted - see the
## pass_exam objective note below). No new gameplay signals were needed;
## this phase is almost entirely about giving existing signals structured
## meaning, not inventing new plumbing.
##
## TWO-PHASE COMPLETION (matches the brief's explicit
## "Fish collected -> Return to NPC -> Receive reward" flow): satisfying
## every objective does NOT complete the quest by itself. It only sets a
## progress flag and fires EventBus.quest_objectives_completed, so an NPC
## dialogue condition can detect "ready to turn in" and offer a distinct
## conversation branch. The quest is only actually completed - and its
## reward granted - when turn_in_quest() runs, which happens via the
## "complete_quest" dialogue action (see NPCManager.gd - its handler for
## that action type now calls turn_in_quest() here instead of calling
## QuestManager.complete_quest() directly).
##
## DATA LOCATION: Data/JSON/Quests/*.json - see README_QUEST_SYSTEM.md for
## the full schema and all supported objective types.

const QUEST_JSON_DIR := "res://Data/JSON/Quests/"

# quest_id -> quest definition Dictionary
var _quest_definitions: Dictionary = {}


func _ready() -> void:
	_load_all_quests()

	EventBus.item_added.connect(_on_item_added)
	EventBus.region_changed.connect(_on_region_changed)
	EventBus.question_answered.connect(_on_question_answered)
	EventBus.exam_completed.connect(_on_exam_completed)


func _load_all_quests() -> void:
	var dir := DirAccess.open(QUEST_JSON_DIR)
	if dir == null:
		push_warning("QuestObjectiveManager: no Quests JSON directory found yet at %s" % QUEST_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open(QUEST_JSON_DIR + file_name, FileAccess.READ)
			if file == null:
				file_name = dir.get_next()
				continue
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("quest_id"):
				_quest_definitions[parsed["quest_id"]] = parsed
			else:
				push_warning("QuestObjectiveManager: %s missing required field 'quest_id'" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Called by NPCManager's "complete_quest" dialogue action. Marks the
## quest completed, grants its reward (if the definition has one), and
## auto-starts next_quest_id (if set). If no definition exists for this
## quest_id at all, this still calls QuestManager.complete_quest() and
## simply grants no reward - a safe, backward-compatible fallback so any
## quest_id used with "complete_quest" before this phase existed keeps
## working exactly as before.
func turn_in_quest(quest_id: String) -> void:
	QuestManager.complete_quest(quest_id)

	if not _quest_definitions.has(quest_id):
		return

	var def: Dictionary = _quest_definitions[quest_id]
	var reward: Dictionary = def.get("reward", {})
	if reward.has("item_id"):
		InventoryManager.add_item(reward.get("item_id", ""), reward.get("amount", 1))

	var next_quest_id: String = def.get("next_quest_id", "")
	if next_quest_id != "":
		QuestManager.start_quest(next_quest_id)


func _on_item_added(item_id: String, _amount: int) -> void:
	print("Item added: ", item_id)
	_check_active_quests("catch_fish", {"fish_id": item_id})


func _on_region_changed(_old_region_id: String, new_region_id: String) -> void:
	_check_active_quests("visit_location", {"region_id": new_region_id})


func _on_question_answered(question_id: String, was_correct: bool) -> void:
	if not was_correct:
		return
	_check_active_quests("answer_questions", {"question_id": question_id})


## "pass_exam" objectives listen for this, but nothing currently emits it -
## EventBus.exam_completed is a hook declared since the original framework
## pass, waiting on a real ExamManager (same status as NPCManager's
## "start_exam" action). This handler is correct and ready; it just has no
## real events to react to yet.
func _on_exam_completed(exam_id: String, score: float) -> void:
	_check_active_quests("pass_exam", {"exam_id": exam_id, "score": score})


func _check_active_quests(objective_type: String, event_data: Dictionary) -> void:
	for quest_id in _quest_definitions:
		if QuestManager.get_quest_state(quest_id) != "active":
			continue

		var def: Dictionary = _quest_definitions[quest_id]
		var objectives: Array = def.get("objectives", [])
		var any_matched := false

		for objective in objectives:
			if objective.get("type", "") != objective_type:
				continue
			if _event_matches_objective(objective_type, objective, event_data):
				any_matched = true

		if any_matched:
			_advance_progress(quest_id, def, objective_type, event_data)


func _event_matches_objective(objective_type: String, objective: Dictionary, event_data: Dictionary) -> bool:
	match objective_type:
		"catch_fish":
			return objective.get("fish_id", "") == event_data.get("fish_id", "")
		"visit_location":
			return objective.get("region_id", "") == event_data.get("region_id", "")
		"answer_questions":
			# Generic count of any correct answer - lesson_id filtering is
			# intentionally not implemented yet (would need QuestionManager
			# to expose per-question lesson_id lookup at this call site;
			# get_question_by_id() already supports it, this is a small
			# follow-up if per-lesson quest objectives are wanted later).
			return true
		"pass_exam":
			var passing_score: float = objective.get("passing_score", 0.6)
			return objective.get("exam_id", "") == event_data.get("exam_id", "") \
				and event_data.get("score", 0.0) >= passing_score
	return false


## Increments progress for every objective (by index) that matches this
## event, then checks whether the whole quest is now ready to turn in.
func _advance_progress(quest_id: String, def: Dictionary, objective_type: String, event_data: Dictionary) -> void:
	var progress: Dictionary = QuestManager.get_quest_progress(quest_id).duplicate(true)
	var objectives: Array = def.get("objectives", [])

	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		if objective.get("type", "") != objective_type:
			continue
		if not _event_matches_objective(objective_type, objective, event_data):
			continue
		var key := "obj_%d" % i
		progress[key] = progress.get(key, 0) + 1

	QuestManager.update_quest_progress(quest_id, progress)
	_check_all_objectives_complete(quest_id, def, progress)


func _check_all_objectives_complete(quest_id: String, def: Dictionary, progress: Dictionary) -> void:
	if progress.get("objectives_complete", false):
		return  # already marked - don't re-fire the signal every time

	var objectives: Array = def.get("objectives", [])
	for i in range(objectives.size()):
		var required: int = objectives[i].get("count", 1)
		var key := "obj_%d" % i
		if progress.get(key, 0) < required:
			return  # at least one objective still incomplete

	print("Objectives complete for: ", quest_id)
	progress["objectives_complete"] = true
	QuestManager.update_quest_progress(quest_id, progress)
	EventBus.quest_objectives_completed.emit(quest_id)
