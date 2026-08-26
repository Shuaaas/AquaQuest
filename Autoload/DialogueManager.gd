extends Node
## DialogueManager (Autoload Singleton)
##
## Plays back dialogue sequences loaded from Resources/Dialogue/. Contains
## zero UI code - it only emits signals (dialogue_line_shown, etc.) that a
## DialogueBox UI scene subscribes to. This means the dialogue UI can be
## fully redesigned without ever touching this script, and this script can
## be unit tested headlessly.
##
## Expected dialogue Resource shape (a custom Resource script, e.g.
## DialogueData.gd, is recommended so this stays Godot-native rather than
## raw JSON):
##   lines: Array[Dictionary] -> [{ "speaker": String, "text": String, "choices": Array }]

var _current_dialogue_id: String = ""
var _current_lines: Array = []
var _current_line_index: int = -1
var is_active: bool = false


func start_dialogue(dialogue_id: String, lines: Array) -> void:
	if is_active:
		push_warning("DialogueManager: dialogue already active, ignoring '%s'" % dialogue_id)
		return

	_current_dialogue_id = dialogue_id
	_current_lines = lines
	_current_line_index = -1
	is_active = true

	EventBus.dialogue_started.emit(dialogue_id)
	advance()


## Call this from the UI when the player taps to continue.
func advance() -> void:
	if not is_active:
		return

	_current_line_index += 1
	if _current_line_index >= _current_lines.size():
		_end_dialogue()
		return

	var line: Dictionary = _current_lines[_current_line_index]
	EventBus.dialogue_line_shown.emit(line.get("speaker", ""), line.get("text", ""))


## Call this from the UI when the player picks a dialogue choice.
func choose(choice_index: int) -> void:
	EventBus.dialogue_choice_made.emit(choice_index)
	advance()


func _end_dialogue() -> void:
	var finished_id := _current_dialogue_id
	is_active = false
	_current_dialogue_id = ""
	_current_lines = []
	_current_line_index = -1
	EventBus.dialogue_ended.emit(finished_id)
