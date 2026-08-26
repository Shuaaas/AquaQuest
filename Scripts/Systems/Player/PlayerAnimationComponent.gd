extends Node
class_name PlayerAnimationComponent
## PlayerAnimationComponent
##
## Translates movement state into AnimatedSprite2D animation names. Knows
## nothing about Input, physics, or CharacterBody2D - it only reacts to
## MovementComponent's signals (direction_changed / started_moving /
## stopped_moving / running_state_changed), wired by Player.gd. Swap the
## sprite art or animation set without touching movement logic, and vice
## versa.
##
## ANIMATION NAMING CONVENTION expected in the assigned SpriteFrames
## (3-pose sheet: only up/down/side are drawn, left and right share the
## "side" pose and are mirrored via flip_h instead of separate frames):
##   idle_down, idle_up, idle_side
##   walk_down, walk_up, walk_side
##   run_down,  run_up,  run_side
## If you later author true separate left/right frames instead, only
## _facing_to_suffix() below needs to change back - nothing else in this
## script, or anywhere outside it, depends on which convention is used.

@export var animated_sprite: AnimatedSprite2D

var _is_moving: bool = false
var _is_running: bool = false
var _facing: Vector2 = Vector2.DOWN
var _equipped_item: String = ""


## Wired to FishingRodComponent.equipped_changed (and reusable for any
## future equippable). If a "<prefix>_<suffix>_<item_id>" animation exists
## (e.g. "idle_down_fishing_rod") it's preferred; otherwise this falls back
## to the base animation so nothing breaks before that art exists.
func on_equipment_changed(item_id: String) -> void:
	_equipped_item = item_id
	_update_animation()


func on_direction_changed(direction: Vector2) -> void:
	_facing = direction
	_update_animation()


func on_started_moving() -> void:
	_is_moving = true
	_update_animation()


func on_stopped_moving() -> void:
	_is_moving = false
	_update_animation()


func on_running_state_changed(is_running: bool) -> void:
	_is_running = is_running
	_update_animation()


func _update_animation() -> void:
	if animated_sprite == null:
		return
	var suffix := _facing_to_suffix(_facing)
	var prefix := "idle"
	if _is_moving:
		prefix = "run" if _is_running else "walk"
	var anim_name := "%s_%s" % [prefix, suffix]
	if _equipped_item != "" and animated_sprite.sprite_frames:
		var equipped_variant := "%s_%s" % [anim_name, _equipped_item]
		if animated_sprite.sprite_frames.has_animation(equipped_variant):
			anim_name = equipped_variant

	if suffix == "side":
		animated_sprite.flip_h = _facing.x < 0

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		push_warning("PlayerAnimationComponent: missing animation '%s'" % anim_name)


func _facing_to_suffix(direction: Vector2) -> String:
	# Pick the dominant axis so diagonal input still resolves to one of the
	# 3 available poses (up / down / side).
	if absf(direction.x) > absf(direction.y):
		return "side"
	elif direction.y != 0:
		return "down" if direction.y > 0 else "up"
	return "down"
