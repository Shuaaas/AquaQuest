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
var _previous_focus: WeakRef


func _ready() -> void:
	# Added retroactively (Phase 12): dialogue itself never pauses gameplay,
	# but a dialogue action CAN trigger something that does (e.g. "start_exam"
	# firing mid-conversation, before this dialogue node has actually ended).
	# Without this, DialogueUI's Continue/choice buttons freeze the instant
	# that happens, since Godot pauses every node by default. FishingUI and
	# ExamUI already had this fix from when pausing was introduced (Phase 8)
	# - this scene predates that phase and was never retrofitted until now.
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Copy source data only; duplicating a live font also copies its glyph cache.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	resized.connect(_layout)
	%DialoguePanel.minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()
	continue_button.pressed.connect(_on_continue_pressed)

	EventBus.dialogue_line_shown.connect(_on_line_shown)
	EventBus.dialogue_choices_presented.connect(_on_choices_presented)
	EventBus.dialogue_portrait_changed.connect(_on_portrait_changed)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_line_shown(speaker: String, text: String) -> void:
	if not visible:
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null else null
	visible = true
	%ScrollContainer.scroll_vertical = 0
	%Nameplate.visible = not speaker.is_empty()
	speaker_label.text = speaker
	dialogue_text_label.text = text

	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	continue_button.visible = false
	_choices_pending = false

	# See class doc SEQUENCING NOTE - deferred so dialogue_choices_presented
	# (if it's coming) has already run by the time this executes.
	call_deferred("_finalize_line_display")


func _finalize_line_display() -> void:
	if not visible:
		return
	_layout()
	if not _choices_pending:
		continue_button.visible = true
		%Hint.text = "Take your time to read."
		continue_button.grab_focus()
	else:
		%Hint.text = "Choose a response."
		if choices_container.get_child_count() > 0:
			choices_container.get_child(0).grab_focus()
	# Initial focus must not skip a long lesson by scrolling directly to its choices.
	%ScrollContainer.set_deferred("scroll_vertical", 0)
	_layout.call_deferred()


func _on_choices_presented(choices: Array) -> void:
	_choices_pending = true
	continue_button.visible = false

	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var choice_button := Button.new()
		choice_button.custom_minimum_size.y = 48
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.add_theme_font_size_override("font_size", 18)
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
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var origin := Vector2(DisplayServer.window_get_position())
		var transform := get_viewport().get_screen_transform().affine_inverse()
		bounds = bounds.intersection(
			Rect2(
				transform * (Vector2(safe.position) - origin),
				(
					transform * (Vector2(safe.end) - origin)
					- transform * (Vector2(safe.position) - origin)
				)
			)
		)
	var margin := 12.0 if bounds.size.y < 500 or bounds.size.x < 700 else 24.0
	bounds = bounds.grow(-margin)
	var width := minf(1080, bounds.size.x)
	var height := minf(420, bounds.size.y * (0.86 if size.y < 500 else 0.52))
	%DialoguePanel.size = Vector2(width, height)
	%DialoguePanel.position = Vector2(
		bounds.get_center().x - width / 2, bounds.end.y - %DialoguePanel.size.y
	)
	%Nameplate.custom_minimum_size.x = minf(220, width - 32)
	%Footer.visible = continue_button.visible or size.y >= 450
