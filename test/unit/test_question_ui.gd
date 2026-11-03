extends GutTest
const FISHING := preload("res://Scene/UI/fishing_ui.tscn")
const EXAM := preload("res://Scene/UI/exam_ui.tscn")
var host: Control
var fishing: FishingUI
var exam: ExamUI
var original: Dictionary


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = {
		"points": FishingManager._get_points_save_data().duplicate(true),
		"dda": DDAController._get_save_data().duplicate(true),
		"hint_counter": DDAController._questions_since_last_hint,
		"inventory": InventoryManager._get_save_data().duplicate(true),
		"quests": QuestManager._get_save_data().duplicate(true),
		"history": ExamManager._get_save_data().duplicate(true),
		"exam_defs": ExamManager._exam_definitions.duplicate(true),
		"performance": PerformanceTracker._get_save_data().duplicate(true),
		"state": GameManager.current_state
	}
	GameManager.current_state = GameManager.GameState.PLAYING
	DDAController.current_tier = DDAController.DifficultyTier.EASY
	FishingManager._apply_points_save_data({"points": 100, "total_earned": 100, "total_spent": 0})
	host = Control.new()
	host.size = Vector2(1200, 760)
	add_child(host)
	fishing = FISHING.instantiate()
	host.add_child(fishing)
	exam = EXAM.instantiate()
	host.add_child(exam)


func after_each() -> void:
	GameManager.set_paused(false)
	host.free()
	FishingManager._reset_to_idle()
	ExamManager._is_active = false
	ExamManager._current_exam_id = ""
	ExamManager._current_questions = []
	ExamManager._current_question_index = -1
	ExamManager._current_correct_count = 0
	ExamManager._exam_definitions = original.exam_defs
	ExamManager._apply_save_data(original.history)
	FishingManager._apply_points_save_data(original.points)
	InventoryManager._apply_save_data(original.inventory)
	QuestManager._apply_save_data(original.quests)
	DDAController._apply_save_data(original.dda)
	DDAController._questions_since_last_hint = original.hint_counter
	PerformanceTracker._apply_save_data(original.performance)
	GameManager.current_state = original.state
	await get_tree().process_frame


func settle() -> void:
	for frame in 12:
		await get_tree().process_frame


func question() -> Dictionary:
	return QuestionManager.get_question_by_id("r1_001").duplicate(true)


func test_fishing_points_hint_and_optional_image_presentation() -> void:
	var data := question()
	fishing._display_question(data, false)
	await settle()
	assert_eq(fishing.points_label.text, "Points: 100")
	assert_true(fishing.hint_button.visible)
	fishing.hint_button.pressed.emit()
	assert_true(fishing.get_node("%HintPanel").visible)
	assert_eq(fishing.hint_label.text, data.hint)
	assert_false(fishing.hint_button.visible)
	assert_eq(FishingManager.get_points(), 100)
	data.image = "res://missing-question-preview.png"
	fishing._display_question(data, false)
	assert_false(fishing.question_image.visible)
	assert_false(fishing.get_node("%HintPanel").visible)
	data.image = "res://Assets/UI/Items/fishing_rod.svg"
	fishing._display_question(data, false)
	assert_true(fishing.question_image.visible)
	DDAController.current_tier = DDAController.DifficultyTier.HARD
	fishing._display_question(data, false)
	assert_false(fishing.hint_button.visible)


func test_medium_hint_frequency_is_consulted_once_per_question() -> void:
	DDAController.current_tier = DDAController.DifficultyTier.MEDIUM
	DDAController._questions_since_last_hint = 0
	fishing._display_question(question(), false)
	assert_false(fishing.hint_button.visible)
	assert_eq(DDAController._questions_since_last_hint, 1)
	fishing._display_question(question(), false)
	assert_true(fishing.hint_button.visible)
	assert_eq(DDAController._questions_since_last_hint, 0)


func test_wrong_fishing_answer_reviews_then_resumes_original_question() -> void:
	watch_signals(EventBus)
	var data := question()
	FishingManager._current_question = data
	FishingManager._current_spot_id = "gut_question_ui"
	FishingManager._state = FishingManager.FlowState.AWAITING_MAIN_ANSWER
	GameManager.set_paused(true)
	fishing._display_question(data, false)
	(
		fishing
		. choices_container
		. get_child((int(data.correct_index) + 1) % data.choices.size())
		. pressed
		. emit()
	)
	assert_eq(FishingManager._state, FishingManager.FlowState.AWAITING_MINI_ANSWER)
	assert_true(fishing.visible)
	assert_true(fishing.get_node("%ReviewBanner").visible)
	assert_eq(fishing.question_label.text, FishingManager._current_mini_question.text)
	var mini := FishingManager._current_mini_question.duplicate(true)
	fishing.choices_container.get_child(int(mini.correct_index)).pressed.emit()
	assert_eq(FishingManager._state, FishingManager.FlowState.AWAITING_MAIN_ANSWER)
	assert_true(fishing.visible)
	assert_false(fishing.get_node("%ReviewBanner").visible)
	assert_eq(fishing.question_label.text, data.text)
	assert_true(get_tree().paused)
	assert_signal_not_emitted(EventBus, "ui_notification_requested")


func test_correct_fishing_answer_hides_before_reeling_and_prevents_double_submit() -> void:
	watch_signals(EventBus)
	var data := question()
	FishingManager._current_question = data
	FishingManager._current_spot_id = "gut_question_ui"
	FishingManager._state = FishingManager.FlowState.AWAITING_MAIN_ANSWER
	GameManager.set_paused(true)
	fishing._display_question(data, false)
	var observed := {"hidden": false}
	var on_reel := func(_spot, _success): observed.hidden = not fishing.visible
	EventBus.fishing_reel_started.connect(on_reel)
	fishing._on_choice_pressed(int(data.correct_index))
	assert_true(observed.hidden)
	assert_eq(FishingManager._state, FishingManager.FlowState.REELING)
	var balance := FishingManager.get_points()
	fishing._on_choice_pressed(int(data.correct_index))
	assert_eq(FishingManager.get_points(), balance)
	await get_tree().create_timer(FishingManager.REEL_DURATION_SECONDS + 0.1).timeout
	assert_eq(FishingManager._state, FishingManager.FlowState.IDLE)
	EventBus.fishing_reel_started.disconnect(on_reel)
	assert_signal_not_emitted(EventBus, "ui_notification_requested")


func start_exam() -> void:
	ExamManager._exam_definitions["gut_question_ui"] = {"passing_score": 0.7, "next_region_id": ""}
	ExamManager._current_exam_id = "gut_question_ui"
	ExamManager._current_questions = [question(), QuestionManager.get_question_by_id("r1_002")]
	ExamManager._current_question_index = -1
	ExamManager._current_correct_count = 0
	ExamManager._is_active = true
	GameManager.set_paused(true)
	ExamManager._show_next_question()


func test_exam_questions_and_results_use_actual_manager_scores() -> void:
	start_exam()
	await settle()
	assert_eq(exam.progress_label.text, "Question 1 of 2")
	assert_eq(exam.get_node("%QuestionProgress").value, 0.0)
	assert_false(exam.close_button.visible)
	assert_false(exam.has_node("%HintButton"))
	assert_eq(get_viewport().gui_get_focus_owner(), exam.choices_container.get_child(0))
	exam.choices_container.get_child(int(question().correct_index)).pressed.emit()
	assert_eq(exam.progress_label.text, "Question 2 of 2")
	assert_eq(exam.get_node("%QuestionProgress").value, 50.0)
	var second: Dictionary = ExamManager._current_questions[1]
	(
		exam
		. choices_container
		. get_child((int(second.correct_index) + 1) % second.choices.size())
		. pressed
		. emit()
	)
	await settle()
	assert_true(exam.get_node("%ResultSummary").visible)
	assert_eq(exam.get_node("%ScoreLabel").text, "50% · 1 / 2 correct")
	assert_eq(exam.get_node("%ResultHeadline").text, "Keep learning")
	assert_false(get_tree().paused)
	assert_eq(ExamManager.get_exam_history("gut_question_ui")[-1].score, 0.5)
	assert_eq(get_viewport().gui_get_focus_owner(), exam.close_button)
	exam.close_button.pressed.emit()
	assert_false(exam.visible)
	start_exam()
	for index in 2:
		var current: Dictionary = ExamManager._current_questions[
			ExamManager._current_question_index
		]
		exam.choices_container.get_child(int(current.correct_index)).pressed.emit()
	assert_eq(exam.get_node("%ScoreLabel").text, "100% · 2 / 2 correct")
	assert_eq(exam.get_node("%ResultHeadline").text, "Passed!")
	assert_eq(ExamManager.get_exam_history("gut_question_ui")[-1].score, 1.0)


func test_long_questions_scroll_reset_and_controls_fit_supported_sizes() -> void:
	var data := question()
	data.text = "Long question layout verification. ".repeat(70)
	data.choices = ["First long answer choice. ".repeat(8), "Second answer"]
	for screen in [fishing, exam]:
		for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844)]:
			host.size = dimensions
			if screen == fishing:
				fishing._display_question(data, false)
			else:
				exam._on_question_ready("layout", 1, 2, data)
			await settle()
			assert_true(
				Rect2(Vector2.ZERO, dimensions).encloses(screen.get_node("%Panel").get_rect()),
				str(dimensions)
			)
			assert_eq(screen.get_node("%ScrollContainer").scroll_vertical, 0)
			for button in screen.choices_container.get_children():
				assert_gte(button.size.y, 48.0)
			screen.get_node("%ScrollContainer").scroll_vertical = 300
			assert_gt(screen.get_node("%ScrollContainer").scroll_vertical, 0)
			assert_true(screen.can_process())
		screen.hide()


func test_fishing_access_notices_still_use_toast() -> void:
	watch_signals(EventBus)
	fishing._on_fishing_denied("test_spot", "rod_not_equipped")
	assert_signal_emitted_with_parameters(EventBus, "ui_notification_requested", ["Equip your fishing rod first.", 2.0])
