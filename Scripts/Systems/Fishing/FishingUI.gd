extends Control
class_name FishingUI
## FishingUI
##
## Displays the fishing question overlay - both the MAIN question and the
## Mini Quest question triggered by a wrong answer. Knows nothing about
## fishing FLOW (that's FishingManager's job) or question DATA (that's
## QuestionManager's job) - it only reacts to EventBus signals and calls
## FishingManager.submit_answer()/submit_mini_quest_answer() when the
## player picks a choice. This is the one and only place in the whole
## fishing feature allowed to touch Control nodes.
##
## SEQUENCING (important): the card hides IMMEDIATELY the instant the
## player picks a choice - it does NOT wait for fishing_ended. This is
## deliberate: FishingManager's REELING state (the "dragging the rod"
## completion animation) is meant to be the visual payoff moment, and it
## should play with the question card already gone, not underneath it.
## The result ("Caught it!"/"It got away.") is shown as a brief toast via
## UIManager once fishing_ended actually fires, after the reel animation
## has already played.
##
## PAUSE-SAFE BY CONSTRUCTION (Phase 8): FishingManager now calls
## GameManager.set_paused(true) the moment a question appears, per your
## brief's "Pause gameplay" step. Godot's default Process Mode (Inherit)
## would make every node, including this Control and its buttons, stop
## receiving input the instant the tree pauses - which would make the
## question unanswerable. Rather than requiring a manual Inspector step
## that could be forgotten, _ready() below sets this scene's Process Mode
## to "Always" in code, guaranteeing it every time this scene loads.
##
## SETUP: attach to the FishingUI.tscn root (a Control). Requires
## QuestionLabel and ChoicesContainer to be marked "Access as Unique Name"
## in the scene tree - see README_PLAYER_SYSTEM.md style setup notes for
## this pattern.
##
## OPTIONAL: a Label named "PointsLabel" (also unique-named) will show the
## running fishing score if present - entirely optional, safe to omit.
## A "ResultLabel" is no longer required (see CHANGE note below) but is
## harmless to leave in your scene if you already added it.
##
## CHANGE FROM EARLIER VERSION: previously, a ResultLabel showed the
## outcome text INSIDE the card for 1.2 seconds before hiding. That's been
## replaced by hiding immediately on answer + a toast notification after
## fishing_ended, per the sequencing note above. If you want the result
## shown differently (e.g. back inside the card, timed to appear AFTER the
## reel animation instead of as a toast), _on_fishing_ended() below is the
## one place to change.
##
## This scene should exist somewhere in your game's persistent UI layer
## (e.g. instanced as a child of your HUD/root UI scene) so it's always
## present to listen for EventBus signals, starting hidden.

@onready var question_label: Label = %QuestionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var points_label: Label = get_node_or_null("%PointsLabel")

var _answered: bool = false
var _is_mini_quest: bool = false


func _ready() -> void:
	# Set here in code, not left to a manual Inspector step - guarantees
	# this can't be silently forgotten. See the CRITICAL SETUP STEP note
	# in the class doc above for why this specific mode is required.
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	EventBus.fishing_question_ready.connect(_on_question_ready)
	EventBus.mini_quest_question_ready.connect(_on_mini_quest_ready)
	EventBus.fishing_denied.connect(_on_fishing_denied)
	EventBus.fishing_ended.connect(_on_fishing_ended)
	EventBus.fishing_points_changed.connect(_on_points_changed)


func _on_question_ready(_spot_id: String, question: Dictionary) -> void:
	_display_question(question, false)


func _on_mini_quest_ready(_spot_id: String, question: Dictionary) -> void:
	_display_question(question, true)


func _display_question(question: Dictionary, is_mini_quest: bool) -> void:
	_answered = false
	_is_mini_quest = is_mini_quest
	visible = true

	# Cheap framing distinction without requiring a new UI node - prepend a
	# tag so the player can tell this is the "second chance" question. A
	# dedicated label/banner would look nicer; this is the zero-scene-change
	# option so it works the moment this script is dropped in.
	var prefix := "Mini Quest! " if is_mini_quest else ""
	question_label.text = prefix + question.get("text", "")

	for child in choices_container.get_children():
		child.queue_free()

	var choices: Array = question.get("choices", [])
	for i in range(choices.size()):
		var choice_button := Button.new()
		choice_button.text = str(choices[i])
		choice_button.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(choice_button)


func _on_choice_pressed(choice_index: int) -> void:
	if _answered:
		return
	_answered = true

	# Hide FIRST, synchronously, before calling into FishingManager. Both
	## submit_answer() and submit_mini_quest_answer() run everything up to
	# their first `await` on this same call stack, so the card is already
	# gone before the REELING state (and its animation) even begins.
	visible = false

	if _is_mini_quest:
		FishingManager.submit_mini_quest_answer(choice_index)
	else:
		FishingManager.submit_answer(choice_index)


func _on_fishing_ended(_spot_id: String, success: bool) -> void:
	# By the time this fires, the REELING animation has already finished
	# playing (FishingManager awaits the reel duration before emitting
	# this) and the card has been hidden since the moment the player
	# answered. This is purely a result toast, not a card state change.
	var message := "Caught it!" if success else "It got away."
	UIManager.show_notification(message, 1.5)


func _on_fishing_denied(_spot_id: String, reason: String) -> void:
	# This fires before any question ever appears (no rod, no active quest,
	# no question available, etc.) - relay it as a toast, same as the
	# result message above.
	var message := "Can't fish right now."
	if reason == "rod_not_equipped":
		message = "Equip your fishing rod first."
	elif reason == "wrong_rod_equipped":
		message = "You need a different rod for this spot."
	elif reason == "quest_not_active":
		message = "You need to accept the right quest first."
	elif reason == "no_question_available":
		message = "No questions available for this spot yet."
	UIManager.show_notification(message, 2.0)


func _on_points_changed(new_total: int, _delta: int) -> void:
	if points_label:
		points_label.text = "Points: %d" % new_total
