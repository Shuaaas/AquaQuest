extends Control
class_name DialogueUI
## DialogueUI
##
## Displays NPC dialogue - speaker name, line text, and either choice
## buttons or a Continue prompt depending on what the current node has.
## Knows nothing about NPCs, quests, or what an "action" means (that's
## NPCManager's job) or how branching/traversal works (that's
## DialogueManager's job) - it only reacts to EventBus signals and calls
## DialogueManager.choose()/advance() when the player responds. This is
## the one and only place in the whole NPC feature allowed to touch
## Control nodes.
##
## SEQUENCING NOTE: DialogueManager emits dialogue_line_shown first, and
## ONLY THEN emits dialogue_choices_presented if the node actually has
## choices - a node with no choices never fires that second signal at
## all. Since both signals (when they both fire) do so synchronously in
## the same call stack, this script can't know while handling
## dialogue_line_shown whether choices are coming right after it. It
## solves this with call_deferred - deciding whether to show the Continue
## button only after the current signal cascade has fully finished.
##
## SETUP: attach to the DialogueUI.tscn root (a Control). Requires
## SpeakerLabel, DialogueTextLabel, ChoicesContainer, and ContinueButton
## to be marked "Access as Unique Name". A PortraitRect is optional - safe
## to omit entirely.

@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_text_label: Label = %DialogueTextLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var continue_button: Button = %ContinueButton
@onready var portrait_rect: TextureRect = get_node_or_null("%PortraitRect")

var _choices_pending: bool = false


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)

	EventBus.dialogue_line_shown.connect(_on_line_shown)
	EventBus.dialogue_choices_presented.connect(_on_choices_presented)
	EventBus.dialogue_portrait_changed.connect(_on_portrait_changed)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_line_shown(speaker: String, text: String) -> void:
	visible = true
	speaker_label.text = speaker
	dialogue_text_label.text = text

	for child in choices_container.get_children():
		child.queue_free()
	continue_button.visible = false
	_choices_pending = false

	# See class doc SEQUENCING NOTE - deferred so dialogue_choices_presented
	# (if it's coming) has already run by the time this executes.
	call_deferred("_finalize_line_display")


func _finalize_line_display() -> void:
	if not _choices_pending:
		continue_button.visible = true


func _on_choices_presented(choices: Array) -> void:
	_choices_pending = true
	continue_button.visible = false

	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var choice_button := Button.new()
		choice_button.text = str(choice.get("text", ""))
		choice_button.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(choice_button)


func _on_choice_pressed(choice_index: int) -> void:
	DialogueManager.choose(choice_index)


func _on_continue_pressed() -> void:
	DialogueManager.advance()


func _on_portrait_changed(portrait_path: String) -> void:
	if portrait_rect == null:
		return
	if portrait_path == "":
		portrait_rect.visible = false
		return
	portrait_rect.texture = load(portrait_path)
	portrait_rect.visible = true


func _on_dialogue_ended(_dialogue_id: String) -> void:
	visible = false
