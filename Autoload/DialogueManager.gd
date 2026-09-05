extends Node
## DialogueManager (Autoload Singleton)
##
## Plays back dialogue. Contains zero UI code - it only emits signals that
## a DialogueBox UI scene subscribes to. This script is intentionally
## agnostic about WHAT a dialogue means (quests, rewards, NPC roles) - see
## NPCManager for that interpretation layer. Supports two independent modes:
##
## LINEAR MODE (start_dialogue/advance/choose with an Array of lines) - the
## original, simplest form: play a fixed sequence of lines in order. This
## mode's behavior is 100% unchanged from the original implementation.
##
## TREE MODE (start_dialogue_tree) - branching dialogue driven by a node
## graph, where each node can present choices leading to different next
## nodes, and can carry "actions" (interpreted by NPCManager, not here)
## that fire the moment the node is entered. Added for the NPC System -
## see README_NPC_SYSTEM.md for the full JSON node schema.

var _current_dialogue_id: String = ""
var is_active: bool = false

# --- Linear mode state (unchanged from the original implementation) ---
var _current_lines: Array = []
var _current_line_index: int = -1

# --- Tree mode state (added for the NPC System) ---
var _tree_nodes: Dictionary = {}
var _current_node_id: String = ""
var _in_tree_mode: bool = false


func start_dialogue(dialogue_id: String, lines: Array) -> void:
	if is_active:
		push_warning("DialogueManager: dialogue already active, ignoring '%s'" % dialogue_id)
		return

	_current_dialogue_id = dialogue_id
	_current_lines = lines
	_current_line_index = -1
	_in_tree_mode = false
	is_active = true

	EventBus.dialogue_started.emit(dialogue_id)
	advance()


## Starts a branching dialogue. `nodes` is the full node dictionary from a
## dialogue tree's already-chosen dialogue_state (NPCManager picks which
## state applies before calling this), and `start_node_id` is which node
## to enter first.
func start_dialogue_tree(dialogue_id: String, nodes: Dictionary, start_node_id: String) -> void:
	if is_active:
		push_warning("DialogueManager: dialogue already active, ignoring '%s'" % dialogue_id)
		return

	_current_dialogue_id = dialogue_id
	_tree_nodes = nodes
	_in_tree_mode = true
	is_active = true

	EventBus.dialogue_started.emit(dialogue_id)
	_enter_node(start_node_id)


## Call this from the UI when the player taps to continue. In tree mode,
## only meaningful on a node with no choices (a "keep reading" beat) -
## it follows that node's own "next" field.
func advance() -> void:
	if not is_active:
		return

	if _in_tree_mode:
		var node: Dictionary = _tree_nodes.get(_current_node_id, {})
		_enter_node(node.get("next", ""))
		return

	_current_line_index += 1
	if _current_line_index >= _current_lines.size():
		_end_dialogue()
		return

	var line: Dictionary = _current_lines[_current_line_index]
	EventBus.dialogue_line_shown.emit(line.get("speaker", ""), line.get("text", ""))


## Call this from the UI when the player picks a dialogue choice. In tree
## mode this follows the CHOSEN choice's own "next" field - this is the
## actual branching, which the original linear implementation never did
## (its choose() just called advance() regardless of which choice was
## picked). Linear mode below is untouched from the original behavior.
func choose(choice_index: int) -> void:
	if not is_active:
		return

	if _in_tree_mode:
		var node: Dictionary = _tree_nodes.get(_current_node_id, {})
		var choices: Array = node.get("choices", [])
		if choice_index < 0 or choice_index >= choices.size():
			push_warning("DialogueManager: choice_index %d out of range" % choice_index)
			return
		EventBus.dialogue_choice_made.emit(choice_index)
		_enter_node(choices[choice_index].get("next", ""))
		return

	EventBus.dialogue_choice_made.emit(choice_index)
	advance()


func _enter_node(node_id: String) -> void:
	if node_id == "" or not _tree_nodes.has(node_id):
		_end_dialogue()
		return

	_current_node_id = node_id
	var node: Dictionary = _tree_nodes[node_id]
	print("Entered node: ", node_id, " | speaker: ", node.get("speaker",""), " | text: ", node.get("text",""))

	EventBus.dialogue_line_shown.emit(node.get("speaker", ""), node.get("text", ""))

	if node.has("portrait"):
		EventBus.dialogue_portrait_changed.emit(node.get("portrait", ""))

	# Fire once per action, in order. DialogueManager never interprets what
	# an action means - NPCManager listens for this same signal and does
	# the actual work (starting quests, granting items, etc.).
	for action in node.get("actions", []):
		if typeof(action) == TYPE_DICTIONARY:
			EventBus.dialogue_action_triggered.emit(action)

	var choices: Array = node.get("choices", [])
	if not choices.is_empty():
		EventBus.dialogue_choices_presented.emit(choices)


func _end_dialogue() -> void:
	var finished_id := _current_dialogue_id
	is_active = false
	_in_tree_mode = false
	_tree_nodes = {}
	_current_node_id = ""
	_current_dialogue_id = ""
	_current_lines = []
	_current_line_index = -1
	EventBus.dialogue_ended.emit(finished_id)
