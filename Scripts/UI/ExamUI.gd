extends Control
class_name ExamUI
## ExamUI
##
## Displays the Regional Exam - one question at a time, then a
## performance summary (Result Screen) once every question is answered.
## Knows nothing about exam FLOW (that's ExamManager's job) or question
## DATA (QuestionManager's job) - it only reacts to EventBus signals and
## calls ExamManager.submit_exam_answer() when the player picks a choice.
##
## PAUSE-SAFE BY CONSTRUCTION, same reasoning as FishingUI: ExamManager
## calls GameManager.set_paused(true) for the whole exam, so this scene
## sets its own Process Mode to "Always" in code rather than relying on a
## manual Inspector step.
##
## SETUP: attach to the ExamUI.tscn root (a Control). Requires
## ProgressLabel, QuestionLabel, ChoicesContainer, ResultLabel, and
## CloseButton, all marked "Access as Unique Name".
##
## This scene should exist somewhere in your game's persistent UI layer
## (Main.tscn's CanvasLayer, alongside FishingUI/DialogueUI/ToastUI), so
## it's always present to listen for EventBus signals, starting hidden.

@onready var progress_label: Label = %ProgressLabel
@onready var question_label: Label = %QuestionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var result_label: Label = %ResultLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	result_label.visible = false
	close_button.visible = false
	close_button.pressed.connect(_on_close_pressed)

	EventBus.exam_question_ready.connect(_on_question_ready)
	EventBus.exam_result_ready.connect(_on_result_ready)
	EventBus.exam_denied.connect(_on_exam_denied)


func _on_question_ready(_exam_id: String, question_number: int, total_questions: int, question: Dictionary) -> void:
	visible = true
	result_label.visible = false
	close_button.visible = false
	question_label.visible = true
	choices_container.visible = true

	progress_label.text = "Question %d of %d" % [question_number, total_questions]
	question_label.text = question.get("text", "")

	for child in choices_container.get_children():
		child.queue_free()

	var choices: Array = question.get("choices", [])
	for i in range(choices.size()):
		var choice_button := Button.new()
		choice_button.text = str(choices[i])
		choice_button.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(choice_button)


func _on_choice_pressed(choice_index: int) -> void:
	# No awaits inside ExamManager's answer handling, so the very next
	# question (or the result screen) replaces this display synchronously
	# on the same call - no separate "hide immediately" step needed here
	# the way FishingUI required for its animation sequencing.
	ExamManager.submit_exam_answer(choice_index)


func _on_result_ready(_exam_id: String, correct_count: int, total_questions: int, score: float, passed: bool, next_region_id: String) -> void:
	question_label.visible = false
	choices_container.visible = false
	for child in choices_container.get_children():
		child.queue_free()
	progress_label.text = ""

	var percent := int(round(score * 100))
	var headline := "Passed!" if passed else "Not quite."
	var message := "%s You scored %d/%d (%d%%)." % [headline, correct_count, total_questions, percent]

	if passed and next_region_id != "":
		message += " The next region is now unlocked!"
	elif not passed:
		message += " You can try again."

	result_label.text = message
	result_label.visible = true
	close_button.visible = true


func _on_close_pressed() -> void:
	visible = false


func _on_exam_denied(_exam_id: String, reason: String) -> void:
	var message := "Can't start the exam right now."
	if reason == "max_attempts_reached":
		message = "You've used all your attempts for this exam."
	elif reason == "no_questions_available":
		message = "No exam questions are available yet."
	UIManager.show_notification(message, 2.5)
