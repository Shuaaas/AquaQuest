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

const PRESENTATION := preload("res://Scripts/UI/QuestionCardPresentation.gd")

@onready var progress_label: Label = %ProgressLabel
@onready var question_label: Label = %QuestionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var result_label: Label = %ResultLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	PRESENTATION.setup(self)
	result_label.visible = false
	close_button.visible = false
	close_button.pressed.connect(_on_close_pressed)

	EventBus.exam_question_ready.connect(_on_question_ready)
	EventBus.exam_result_ready.connect(_on_result_ready)
	EventBus.exam_denied.connect(_on_exam_denied)


func _on_question_ready(
	_exam_id: String, question_number: int, total_questions: int, question: Dictionary
) -> void:
	visible = true
	%ResultSummary.hide()
	%Title.text = "Regional Examination"
	%Instruction.text = "Select one answer."
	result_label.visible = false
	close_button.visible = false
	question_label.visible = true
	choices_container.visible = true

	progress_label.text = "Question %d of %d" % [question_number, total_questions]
	question_label.text = question.get("text", "")

	%QuestionProgress.value = (
		100.0 * (question_number - 1) / total_questions if total_questions > 0 else 0.0
	)
	PRESENTATION.show_image(self, question.get("image", ""))
	%ScrollContainer.scroll_vertical = 0
	PRESENTATION.add_choices(choices_container, question.get("choices", []), _on_choice_pressed)
	PRESENTATION.focus_question.call_deferred(self)
	PRESENTATION.layout.call_deferred(self)


func _on_choice_pressed(choice_index: int) -> void:
	# No awaits inside ExamManager's answer handling, so the very next
	# question (or the result screen) replaces this display synchronously
	# on the same call - no separate "hide immediately" step needed here
	# the way FishingUI required for its animation sequencing.
	ExamManager.submit_exam_answer(choice_index)


func _on_result_ready(
	_exam_id: String,
	correct_count: int,
	total_questions: int,
	score: float,
	passed: bool,
	next_region_id: String
) -> void:
	question_label.visible = false
	choices_container.visible = false
	PRESENTATION.clear_choices(choices_container)
	%QuestionImage.hide()
	%ResultSummary.show()
	%Title.text = "Examination Results"
	%QuestionProgress.value = 100
	%Instruction.text = "Examination complete."
	progress_label.text = "Completed · %d questions" % total_questions

	var percent := int(round(score * 100))
	var headline := "Passed!" if passed else "Not quite."
	var message := (
		"%s You scored %d/%d (%d%%)." % [headline, correct_count, total_questions, percent]
	)

	if passed and next_region_id != "":
		message += " The next region is now unlocked!"
	elif not passed:
		message += " You can try again."

	%ResultHeadline.text = "Passed!" if passed else "Keep learning"
	%ScoreLabel.text = "%d%% · %d / %d correct" % [percent, correct_count, total_questions]
	result_label.text = message
	result_label.visible = true
	close_button.visible = true
	close_button.grab_focus()
	%ScrollContainer.scroll_vertical = 0
	PRESENTATION.layout.call_deferred(self)


func _on_close_pressed() -> void:
	visible = false


func _on_exam_denied(_exam_id: String, reason: String) -> void:
	var message := "Can't start the exam right now."
	if reason == "quest_not_completed":
		message = "Finish the related quest before taking this exam."
	elif reason == "max_attempts_reached":
		message = "You've used all your attempts for this exam."
	elif reason == "no_questions_available":
		message = "No exam questions are available yet."
	UIManager.show_notification(message, 2.5)
