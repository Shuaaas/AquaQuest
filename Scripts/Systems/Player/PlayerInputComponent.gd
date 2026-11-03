extends Node
class_name PlayerInputComponent
## PlayerInputComponent
##
## The ONLY place in the Player system that touches the Input singleton.
## Every other component reacts to the signals below instead of polling
## Input directly - this means swapping control schemes (touch controls,
## AI-driven input, replay playback, or a remote player's network input)
## only ever requires changing or replacing this one script.
##
## MULTIPLAYER NOTE:
## `set_active(false)` is called by Player.gd on any instance that is NOT
## the local multiplayer authority, so remote players' input components go
## fully idle and never fight the network-synced state.
##
## Required Input Map actions (Project Settings > Input Map):
##   move_up, move_down, move_left, move_right, run, interact, toggle_rod

signal move_input_changed(direction: Vector2)
signal run_input_toggled(is_running: bool)
signal interact_pressed
signal toggle_rod_pressed

var _active: bool = true
var _last_direction: Vector2 = Vector2.ZERO
var _last_run_state: bool = false
var _touch_direction := Vector2.ZERO


func set_active(active: bool) -> void:
	_active = active
	set_process(active)
	set_process_unhandled_input(active)


func _process(_delta: float) -> void:
	if not _active:
		return
	var direction := Vector2.ZERO
	if can_accept_gameplay_input():
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if _touch_direction.length_squared() > direction.length_squared():
			direction = _touch_direction
	if direction != _last_direction:
		_last_direction = direction
		move_input_changed.emit(direction)
	var is_running := can_accept_gameplay_input() and Input.is_action_pressed("run")
	if is_running != _last_run_state:
		_last_run_state = is_running
		run_input_toggled.emit(is_running)


func _unhandled_input(event: InputEvent) -> void:
	if not can_accept_gameplay_input():
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
	if event.is_action_pressed("toggle_rod"):
		toggle_rod_pressed.emit()


## Both touch and keyboard feed the existing movement/interaction signals.
func set_touch_direction(direction: Vector2) -> void:
	_touch_direction = direction.limit_length() if can_accept_gameplay_input() else Vector2.ZERO
	if _touch_direction == Vector2.ZERO and not can_accept_gameplay_input():
		_last_direction = Vector2.ZERO
		move_input_changed.emit(Vector2.ZERO)


func request_interact() -> void:
	if can_accept_gameplay_input():
		interact_pressed.emit()


func can_accept_gameplay_input() -> bool:
	return (
		_active
		and is_inside_tree()
		and not get_tree().paused
		and not DialogueManager.is_active
		and not FishingManager.is_fishing()
		and not SaveManager.is_loading
		and not SceneLoader.is_loading()
		and not MapManager.has_blocking_overlay()
	)
