extends GutTest
## Verifies GUT can run against existing AquaQuest data without changing game state.


func test_question_ids_and_answer_indexes_are_valid() -> void:
	var file := FileAccess.open("res://Data/JSON/Questions/questions_region1.json", FileAccess.READ)
	assert_not_null(file, "The existing question bank must be readable.")
	if file == null:
		return
	var questions = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(questions is Array, "The question bank must contain a JSON array.")
	if not questions is Array:
		return
	assert_gt(questions.size(), 0, "The question bank must not be empty.")
	var seen_ids: Dictionary = {}
	for question in questions:
		assert_true(question is Dictionary, "Each question must be an object.")
		if not question is Dictionary:
			continue
		var question_id: String = question.get("id", "")
		assert_ne(question_id, "", "Each question must have an ID.")
		assert_false(seen_ids.has(question_id), "Question IDs must be unique: " + question_id)
		seen_ids[question_id] = true
		var choices: Array = question.get("choices", [])
		var correct_index: int = int(question.get("correct_index", -1))
		assert_true(
			correct_index >= 0 and correct_index < choices.size(),
			"The correct answer must refer to an existing choice: " + question_id
		)
