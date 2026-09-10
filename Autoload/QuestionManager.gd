extends Node
## QuestionManager (Autoload Singleton)
##
## Single responsibility: load educational question data from
## Data/JSON/Questions/ and answer two questions about it - "give me a
## question at this difficulty tier" and "was this answer correct". It
## does not know that fishing exists, does not know what a Regional Exam
## is, and never touches UI. Both FishingManager and (later) a
## RegionalExamManager can depend on this same question bank without this
## script depending on either of them (Dependency Inversion).
##
## EXPECTED JSON SHAPE (one or more files under Data/JSON/Questions/,
## each an array of question objects):
##   [
##     {
##       "id": "ph_001",
##       "lesson_id": "post_harvest_basics",
##       "tier": 0,                        // 0=EASY, 1=MEDIUM, 2=HARD -
##                                          // MUST match DDAController.DifficultyTier
##       "text": "What temperature should iced fish be stored at?",
##       "image": "res://Assets/Sprites/Questions/iced_fish.png",  // optional (Phase 9)
##       "choices": ["0-4°C", "10-15°C", "20-25°C", "Room temperature"],
##       "correct_index": 0,
##       "explanation": "Keeping fish at 0-4°C slows bacterial growth..."  // optional (Phase 9)
##     }
##   ]
## "image" and "explanation" are both optional (Phase 9 - Educational
## Question System). This script needs NO code changes to support them -
## it already stores each question's full parsed Dictionary as-is, so any
## extra fields ride along automatically. FishingUI.gd is what actually
## reads and displays them.

const QUESTIONS_JSON_DIR := "res://Data/JSON/Questions/"

# question_id -> question Dictionary (fast lookup for evaluate_answer)
var _questions_by_id: Dictionary = {}
# tier (int) -> Array[Dictionary] of questions at that tier
var _questions_by_tier: Dictionary = {}


func _ready() -> void:
	_load_all_questions()


func _load_all_questions() -> void:
	var dir := DirAccess.open(QUESTIONS_JSON_DIR)
	if dir == null:
		push_warning("QuestionManager: no Questions JSON directory found yet at %s" % QUESTIONS_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_question_file(QUESTIONS_JSON_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_question_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("QuestionManager: could not open %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		push_warning("QuestionManager: expected a JSON array in %s" % path)
		return

	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		var question: Dictionary = entry
		_questions_by_id[question["id"]] = question

		var tier: int = question.get("tier", 1)
		if not _questions_by_tier.has(tier):
			_questions_by_tier[tier] = []
		_questions_by_tier[tier].append(question)


## Returns a random question at the given difficulty tier, optionally
## restricted to one lesson_id, and optionally further restricted to an
## explicit list of question ids (added for Phase 8 - "Question Pool" on
## a fishing location definition - default empty means no restriction,
## so every call site written before this phase behaves identically).
## Returns {} if none match - callers must handle that (e.g. FishingManager
## falls back or denies fishing).
func get_random_question(tier: int, lesson_id: String = "", allowed_ids: Array = []) -> Dictionary:
	var pool: Array = _questions_by_tier.get(tier, [])
	if lesson_id != "":
		pool = pool.filter(func(q: Dictionary) -> bool: return q.get("lesson_id", "") == lesson_id)
	if not allowed_ids.is_empty():
		pool = pool.filter(func(q: Dictionary) -> bool: return allowed_ids.has(q.get("id", "")))

	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


func get_question_by_id(question_id: String) -> Dictionary:
	return _questions_by_id.get(question_id, {})


## Evaluates a submitted answer against the stored correct_index. Returns
## false (not an error) if the question_id is unknown, since a caller
## should never treat "unknown question" as "correct".
func evaluate_answer(question_id: String, answer_index: int) -> bool:
	var question := get_question_by_id(question_id)
	if question.is_empty():
		push_warning("QuestionManager: evaluate_answer called with unknown id '%s'" % question_id)
		return false
	return question.get("correct_index", -1) == answer_index
