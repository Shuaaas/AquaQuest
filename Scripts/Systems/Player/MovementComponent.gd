extends Node
class_name MovementComponent
## MovementComponent
##
## Drives a CharacterBody2D's velocity from a direction vector it is told
## about (via set_move_input) - it never reads Input itself, so it works
## identically whether driven by PlayerInputComponent, an AI controller, or
## replicated network state. Assign `body` in the Inspector; no get_node()
## path strings are used anywhere in this script.
##
## Reusable: this same script can drive an NPC's CharacterBody2D too.

signal direction_changed(direction: Vector2)      ## non-zero movement direction
signal facing_changed(facing: Vector2)             ## last non-zero direction (for animation)
signal started_moving
signal stopped_moving
signal running_state_changed(is_running: bool)     ## true only while actually moving AND running

@export var body: CharacterBody2D
@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
@export var acceleration: float = 900.0
@export var friction: float = 1000.0

var facing: Vector2 = Vector2.DOWN
var _move_input: Vector2 = Vector2.ZERO
var _wants_to_run: bool = false
var _can_run: bool = true
var _was_moving: bool = false
var _was_running: bool = false


## Called by whatever drives this component (PlayerInputComponent, AI, network sync).
func set_move_input(direction: Vector2) -> void:
	if direction != _move_input:
		_move_input = direction
		if direction != Vector2.ZERO:
			direction_changed.emit(direction)
			facing = direction
			facing_changed.emit(facing)


func set_run_input(wants_to_run: bool) -> void:
	_wants_to_run = wants_to_run


## Called by StaminaComponent (or any gate) to allow/deny running regardless of input.
func set_can_run(can_run: bool) -> void:
	_can_run = can_run


func _physics_process(_delta: float) -> void:
	if body == null:
		push_warning("MovementComponent: no CharacterBody2D assigned")
		return

	var is_moving := _move_input != Vector2.ZERO
	var is_running := is_moving and _wants_to_run and _can_run

	var target_speed := run_speed if is_running else walk_speed
	var target_velocity := _move_input.normalized() * target_speed if is_moving else Vector2.ZERO
	var accel_rate := acceleration if is_moving else friction

	body.velocity = body.velocity.move_toward(target_velocity, accel_rate * _delta_safe())
	body.move_and_slide()

	if is_moving != _was_moving:
		_was_moving = is_moving
		if is_moving:
			started_moving.emit()
		else:
			stopped_moving.emit()

	if is_running != _was_running:
		_was_running = is_running
		running_state_changed.emit(is_running)


func _delta_safe() -> float:
	return get_physics_process_delta_time()
