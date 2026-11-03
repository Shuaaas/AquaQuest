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
## Answer feedback is handled by the existing fishing/review flow, not ToastUI.
## ToastUI is reserved here for fishing access notices (for example, no equipped rod).
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
## OPTIONAL nodes (all safe to omit - nothing crashes, the feature they
## back just doesn't render):
##   PointsLabel (Label)      - running fishing score
##   QuestionImage (TextureRect) - a question's optional "image" field
##   HintButton (Button)      - shown only if the question has hint text
##                              AND DDAController allows a hint at the
##                              current tier (Phase 11 - see its own doc)
##   HintLabel (Label)        - where hint text appears once HintButton
##                              is pressed
## A "ResultLabel" is no longer used at all (see CHANGE note below).
##
## This scene should exist somewhere in your game's persistent UI layer
## (e.g. instanced as a child of your HUD/root UI scene) so it's always
## present to listen for EventBus signals, starting hidden.

const PRESENTATION := preload("res://Scripts/UI/QuestionCardPresentation.gd")

@onready var question_label: Label = %QuestionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var tier_label: Label = get_node_or_null("%TierLabel")
@onready var points_label: Label = get_node_or_null("%PointsLabel")
@onready var question_image: TextureRect = get_node_or_null("%QuestionImage")
@onready var hint_button: Button = get_node_or_null("%HintButton")
@onready var hint_label: Label = get_node_or_null("%HintLabel")

var _answered: bool = false
var _is_mini_quest: bool = false
## Kept only long enough to populate the hint text when the button is
## pressed - not used anywhere else.
var _current_question_hint: String = ""


func _ready() -> void:
	# Set here in code, not left to a manual Inspector step - guarantees
	# this can't be silently forgotten. See the PAUSE-SAFE note above for
	# why this specific mode is required.
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	PRESENTATION.setup(self)
	_on_points_changed(FishingManager.get_points(), 0)
	EventBus.fishing_question_ready.connect(_on_question_ready)
	EventBus.mini_quest_question_ready.connect(_on_mini_quest_ready)
	EventBus.fishing_denied.connect(_on_fishing_denied)
	EventBus.fishing_points_changed.connect(_on_points_changed)

	if hint_button:
		hint_button.pressed.connect(_on_hint_pressed)
	_update_tier_label()
	EventBus.difficulty_adjusted.connect(_on_difficulty_adjusted)


func _on_question_ready(_spot_id: String, question: Dictionary) -> void:
	_display_question(question, false)


func _on_mini_quest_ready(_spot_id: String, question: Dictionary) -> void:
	_display_question(question, true)


func _display_question(question: Dictionary, is_mini_quest: bool) -> void:
	_answered = false
	_is_mini_quest = is_mini_quest
	visible = true

	%ReviewBanner.visible = is_mini_quest
	%Title.text = "Review Question" if is_mini_quest else "Fishing Question"
	question_label.text = question.get("text", "")
	_on_points_changed(FishingManager.get_points(), 0)
	_update_tier_label()
	_update_question_image(question.get("image", ""))
	_update_hint_availability(question.get("hint", ""))
	%ScrollContainer.scroll_vertical = 0
	PRESENTATION.add_choices(choices_container, question.get("choices", []), _on_choice_pressed)
	PRESENTATION.focus_question.call_deferred(self)
	PRESENTATION.layout.call_deferred(self)


## Phase 11 (DDA Adaptation 2 - Hint Frequency). The button only appears
## at all if BOTH are true: the question actually has hint text authored,
## AND DDAController.should_show_hint() currently allows one for this
## tier. A question with hint text but a HARD-tier player sees no button;
## a question with no hint text sees no button regardless of tier.
func _update_hint_availability(hint_text: String) -> void:
	%HintPanel.hide()
	_current_question_hint = hint_text
	if hint_label:
		hint_label.visible = false
		hint_label.text = ""
	if hint_button == null:
		return
	hint_button.visible = hint_text != "" and DDAController.should_show_hint()


func _on_hint_pressed() -> void:
	%HintPanel.show()
	if hint_label:
		hint_label.text = _current_question_hint
		hint_label.visible = true
	if hint_button:
		hint_button.visible = false
	%ScrollContainer.ensure_control_visible.call_deferred(%HintPanel)


func _update_tier_label() -> void:
	if tier_label == null:
		return
	var names := ["Easy", "Medium", "Hard"]
	var tier: int = DDAController.get_current_tier()
	tier_label.text = "Difficulty: " + names[tier]


func _on_difficulty_adjusted(_new_tier: int, _reason: String) -> void:
	_update_tier_label()


## Shows a question's optional image if one is set AND actually exists on
## disk, hides the slot otherwise - a missing/typo'd path degrades
## gracefully instead of throwing a load error, same philosophy as every
## other optional-art hook in this project (e.g. missing animations just
## warn, never crash).
func _update_question_image(image_path: String) -> void:
	PRESENTATION.show_image(self, image_path)


func _on_choice_pressed(choice_index: int) -> void:
	if _answered:
		return
	_answered = true

	# Hide FIRST, synchronously, before calling into FishingManager. Both
	# submit_answer() and submit_mini_quest_answer() run everything up to
	# their first `await` on this same call stack, so the card is already
	# gone before the REELING state (and its animation) even begins.
	visible = false

	if _is_mini_quest:
		FishingManager.submit_mini_quest_answer(choice_index)
	else:
		FishingManager.submit_answer(choice_index)


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
