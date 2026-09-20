extends Node
## ExamManager (Autoload Singleton)
##
## The Regional Examination System. This is the system flagged as a gap
## all the way back in the NPC System phase - EventBus.exam_started and
## exam_completed have existed since the original framework pass as
## unused hooks, GameManager already switches to IN_EXAM state on them,
## and QuestObjectiveManager's "pass_exam" objective type has been fully
## built and listening since Phase 7. This script is what finally emits
## those signals for real, closing every one of those loops without
## needing to touch any of those three files.
##
## Mirrors FishingManager's design deliberately - a single-attempt state
## machine reacting to a "started" signal, drawing from QuestionManager,
## grading, and funneling every ending path through one helper. Reuses
## the SAME global DDAController tier as fishing (Adaptation 1 - Question
## Difficulty already applies here for free) rather than building a
## second, parallel difficulty tracker - one unified difficulty concept
## for the whole game, not two competing ones.
##
## FLOW:
##   NPCManager's "start_exam" action -> EventBus.exam_started (unchanged
##       signal, now actually consumed)
##     -> checks attempt limit (if the exam defines one) and an active-
##        exam guard, denies with exam_denied if either fails
##     -> GameManager.set_paused(true) (same pattern as fishing)
##     -> draws `question_count` DISTINCT random questions at the current
##        DDA tier (no repeats within one attempt - tracked here, not in
##        QuestionManager, since "no repeats" is an exam-specific rule,
##        not a general QuestionManager concern)
##     -> exam_question_ready, one question at a time -> UI calls
##        submit_exam_answer(index)
##     -> after the last question: computes score, compares to
##        passing_score
##     -> GameManager.set_paused(false)
##     -> exam_result_ready (rich result data for the UI) AND
##        exam_completed (unchanged signature, for QuestObjectiveManager -
##        this is what silently satisfies any "pass_exam" quest objective
##        that's been waiting since Phase 7)
##     -> on a passing score: RegionManager.unlock_region(next_region_id)
##     -> attempt recorded via SaveManager, regardless of pass/fail
##
## RETRY SUPPORT: simply re-triggering "start_exam" (talking to the
## Examiner NPC again) begins a fresh attempt with a newly drawn random
## question set - no special retry method needed, the normal flow already
## handles it. An optional `max_attempts` in the exam definition (0 or
## omitted = unlimited) is checked before allowing a new attempt.
##
## DATA LOCATION: Data/JSON/Exams/*.json - see README_EXAM_SYSTEM.md for
## the full schema.

const EXAM_JSON_DIR := "res://Data/JSON/Exams/"

# exam_id -> exam definition Dictionary
var _exam_definitions: Dictionary = {}

# exam_id -> Array of attempt records: {score, passed, correct_count, total_questions, timestamp}
var _exam_history: Dictionary = {}

var _is_active: bool = false
var _current_exam_id: String = ""
var _current_questions: Array = []
var _current_question_index: int = -1
var _current_correct_count: int = 0


func _ready() -> void:
	_load_all_exams()
	EventBus.exam_started.connect(_on_exam_started)
	SaveManager.register_section("exam_history", _get_save_data, _apply_save_data)


func _load_all_exams() -> void:
	var dir := DirAccess.open(EXAM_JSON_DIR)
	if dir == null:
		push_warning("ExamManager: no Exams JSON directory found yet at %s" % EXAM_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open(EXAM_JSON_DIR + file_name, FileAccess.READ)
			if file == null:
				file_name = dir.get_next()
				continue
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("exam_id"):
				_exam_definitions[parsed["exam_id"]] = parsed
			else:
				push_warning("ExamManager: %s missing required field 'exam_id'" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_exam_started(exam_id: String) -> void:
	if _is_active:
		push_warning("ExamManager: exam_started for '%s' while another exam is active, ignoring" % exam_id)
		return

	if not _exam_definitions.has(exam_id):
		push_error("ExamManager: unknown exam_id '%s'" % exam_id)
		return

	var def: Dictionary = _exam_definitions[exam_id]
	var max_attempts: int = def.get("max_attempts", 0)
	if max_attempts > 0 and _exam_history.get(exam_id, []).size() >= max_attempts:
		EventBus.exam_denied.emit(exam_id, "max_attempts_reached")
		return

	var questions := _draw_distinct_questions(def)
	if questions.is_empty():
		EventBus.exam_denied.emit(exam_id, "no_questions_available")
		return

	_current_exam_id = exam_id
	_current_questions = questions
	_current_question_index = -1
	_current_correct_count = 0
	_is_active = true

	GameManager.set_paused(true)
	_show_next_question()


## Draws up to question_count DISTINCT questions (no repeats within this
## attempt). If the pool is smaller than question_count, returns however
## many distinct questions actually exist rather than looping forever or
## silently repeating one.
func _draw_distinct_questions(def: Dictionary) -> Array:
	var question_count: int = def.get("question_count", 5)
	var tier: int = DDAController.get_current_tier()
	var lesson_id: String = def.get("lesson_id", "")
	var question_pool: Array = def.get("question_pool", [])

	var drawn: Array = []
	var seen_ids: Dictionary = {}
	var max_attempts_to_draw := question_count * 5  # safety cap against an infinite loop on a small pool

	var tries := 0
	while drawn.size() < question_count and tries < max_attempts_to_draw:
		tries += 1
		var question := QuestionManager.get_random_question(tier, lesson_id, question_pool)
		if question.is_empty():
			break
		var question_id: String = question.get("id", "")
		if seen_ids.has(question_id):
			continue
		seen_ids[question_id] = true
		drawn.append(question)

	return drawn


func _show_next_question() -> void:
	_current_question_index += 1
	if _current_question_index >= _current_questions.size():
		_finish_exam()
		return

	var question: Dictionary = _current_questions[_current_question_index]
	EventBus.exam_question_ready.emit(
		_current_exam_id,
		_current_question_index + 1,
		_current_questions.size(),
		question
	)


## Called by the exam UI when the player answers the current question.
func submit_exam_answer(answer_index: int) -> void:
	if not _is_active or _current_question_index < 0 or _current_question_index >= _current_questions.size():
		push_warning("ExamManager: submit_exam_answer called with no active question, ignoring")
		return

	var question: Dictionary = _current_questions[_current_question_index]
	var question_id: String = question.get("id", "")
	var was_correct := QuestionManager.evaluate_answer(question_id, answer_index)
	EventBus.question_answered.emit(question_id, was_correct)

	if was_correct:
		_current_correct_count += 1

	_show_next_question()


func _finish_exam() -> void:
	var exam_id := _current_exam_id
	var def: Dictionary = _exam_definitions.get(exam_id, {})
	var total_questions := _current_questions.size()
	var score: float = float(_current_correct_count) / float(total_questions) if total_questions > 0 else 0.0
	var passing_score: float = def.get("passing_score", 0.7)
	var passed := score >= passing_score
	var next_region_id: String = def.get("next_region_id", "")

	GameManager.set_paused(false)

	_record_attempt(exam_id, score, passed, _current_correct_count, total_questions)

	if passed and next_region_id != "":
		RegionManager.unlock_region(next_region_id)
		
	print("Region 2 unlocked: ", RegionManager.is_region_unlocked("region_2"))
	print("Attempts so far: ", ExamManager.get_attempt_count(exam_id))
	# exam_completed's signature is UNCHANGED from before this phase - this
	# is what silently satisfies QuestObjectiveManager's "pass_exam"
	# objective type, which has been listening since Phase 7.
	EventBus.exam_completed.emit(exam_id, score)
	EventBus.exam_result_ready.emit(exam_id, _current_correct_count, total_questions, score, passed, next_region_id)

	_is_active = false
	_current_exam_id = ""
	_current_questions = []
	_current_question_index = -1
	_current_correct_count = 0


func _record_attempt(exam_id: String, score: float, passed: bool, correct_count: int, total_questions: int) -> void:
	if not _exam_history.has(exam_id):
		_exam_history[exam_id] = []
	_exam_history[exam_id].append({
		"score": score,
		"passed": passed,
		"correct_count": correct_count,
		"total_questions": total_questions,
		"timestamp": Time.get_unix_time_from_system(),
	})


## Public read for a future exam-history UI, or for max_attempts checks.
func get_exam_history(exam_id: String) -> Array:
	return _exam_history.get(exam_id, [])


func get_attempt_count(exam_id: String) -> int:
	return _exam_history.get(exam_id, []).size()


func _get_save_data() -> Dictionary:
	return {"exam_history": _exam_history}


func _apply_save_data(data: Dictionary) -> void:
	_exam_history = data.get("exam_history", {})
