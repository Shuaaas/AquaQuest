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


func set_active(active: bool) -> void:
	_active = active
	set_process(active)
	set_process_unhandled_input(active)


func _process(_delta: float) -> void:
	if not _active:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != _last_direction:
		_last_direction = direction
		move_input_changed.emit(direction)
	var is_running := Input.is_action_pressed("run")
	if is_running != _last_run_state:
		_last_run_state = is_running
		run_input_toggled.emit(is_running)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
	if event.is_action_pressed("toggle_rod"):
		toggle_rod_pressed.emit()
