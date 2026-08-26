extends Node
## GameManager (Autoload Singleton)
##
## Owns the top-level game state (boot, menu, playing, paused, exam, game
## over) and coordinates high-level flow. GameManager does NOT know the
## internals of quests, dialogue, inventory, etc. - it only orchestrates
## via EventBus and public API calls on other autoloads. This keeps it a
## thin coordinator rather than a "god object".

enum GameState {
	BOOT,
	MAIN_MENU,
	PLAYING,
	PAUSED,
	IN_DIALOGUE,
	IN_EXAM,
	GAME_OVER,
}

var current_state: GameState = GameState.BOOT
var is_paused: bool = false


func _ready() -> void:
	EventBus.exam_started.connect(_on_exam_started)
	EventBus.exam_completed.connect(_on_exam_completed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func start_new_game() -> void:
	_change_state(GameState.PLAYING)
	EventBus.game_started.emit()


func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	get_tree().paused = paused
	EventBus.game_paused.emit(paused)
	if paused:
		_change_state(GameState.PAUSED)


func trigger_game_over(reason: String = "") -> void:
	_change_state(GameState.GAME_OVER)
	EventBus.game_over.emit(reason)


func _change_state(new_state: GameState) -> void:
	current_state = new_state


func _on_dialogue_started(_dialogue_id: String) -> void:
	_change_state(GameState.IN_DIALOGUE)


func _on_dialogue_ended(_dialogue_id: String) -> void:
	if current_state == GameState.IN_DIALOGUE:
		_change_state(GameState.PLAYING)


func _on_exam_started(_exam_id: String) -> void:
	_change_state(GameState.IN_EXAM)


func _on_exam_completed(_exam_id: String, _score: float) -> void:
	if current_state == GameState.IN_EXAM:
		_change_state(GameState.PLAYING)
