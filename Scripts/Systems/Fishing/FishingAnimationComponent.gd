extends Node
class_name FishingAnimationComponent
## FishingAnimationComponent
##
## Plays cast/wait fishing poses. Unlike every other Player component,
## this one does NOT get wired by Player.gd's mediator pattern for its
## FLOW signals - it connects directly to EventBus itself in _ready(),
## the same way AudioManager listens directly for play_sfx_requested.
## This is a deliberate exception: fishing_cast_started/fishing_wait_started/
## fish_bit/fishing_ended all originate from FishingManager, an AUTOLOAD,
## not from a sibling component - so there is no sibling for Player.gd to
## relay from. Direct EventBus listening is the simplest correct option at
## the current single-player scope.
##
## It DOES still need Player.gd to wire one thing the normal way: facing
## direction, which comes from MovementComponent (a sibling), so Player.gd
## connects `movement.direction_changed` to `on_direction_changed` below,
## same as it does for PlayerAnimationComponent.
##
## SINGLE-PLAYER SCOPE: assumes only one Player and one fishing session
## exist at a time. A future networked build would need to filter these
## signals to only the player whose session is actually active - out of
## scope for now (same assumption Player.gd's multiplayer authority gating
## already documents elsewhere).
##
## ANIMATION NAMING CONVENTION expected in the assigned SpriteFrames,
## following the same 3-pose (down/up/side) + flip_h convention as
## PlayerAnimationComponent:
##   cast_down, cast_up, cast_side
##   fishing_wait_down, fishing_wait_up, fishing_wait_side
##   reel_down, reel_up, reel_side
## If any of these are missing, this logs a warning and simply leaves
## whatever animation was already playing - it never crashes.

@export var animated_sprite: AnimatedSprite2D

var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	EventBus.fishing_cast_started.connect(_on_cast_started)
	EventBus.fishing_wait_started.connect(_on_wait_started)
	EventBus.fish_bit.connect(_on_fish_bit)
	EventBus.fishing_reel_started.connect(_on_reel_started)
	EventBus.fishing_ended.connect(_on_fishing_ended)


## Wired by Player.gd to MovementComponent.direction_changed.
func on_direction_changed(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing = direction
		if animated_sprite and _suffix() == "side":
			animated_sprite.flip_h = _facing.x < 0


func _on_cast_started(_spot_id: String) -> void:
	_play("cast_%s" % _suffix())


func _on_wait_started(_spot_id: String) -> void:
	_play("fishing_wait_%s" % _suffix())


## Per spec: "Immediately pause the fishing animation" the moment a fish
## bites. stop() freezes on the current frame rather than resetting to
## frame 0, which reads correctly as "paused," not "reset."
func _on_fish_bit(_spot_id: String) -> void:
	if animated_sprite:
		animated_sprite.stop()


## Per spec: "the COMPLETE STATE animation will play like dragging the
## rod" - fires once the player's answer (main OR mini quest) has been
## graded, before the attempt actually ends. `success` is passed through
## in case you want a distinct empty-handed vs. triumphant variant later
## (e.g. "reel_down_fail") - for now this plays one generic reel animation
## regardless of outcome, matching what was actually asked for.
func _on_reel_started(_spot_id: String, _success: bool) -> void:
	_play("reel_%s" % _suffix())


func _on_fishing_ended(_spot_id: String, _success: bool) -> void:
	# Explicitly reassert an idle pose rather than calling animated_sprite.play()
	# with no arguments. That would have ambiguously "resumed" whatever
	# animation was already assigned - by this point that's the one-shot
	# reel clip, which has already finished and has playing=false, so a
	# bare play() would just replay it from its last frame rather than
	# actually handing control back to normal locomotion. Playing idle_*
	# directly guarantees the sprite doesn't get stuck. PlayerAnimationComponent
	# will immediately override this with walk/run on the next movement
	# signal if the player moves right away, so there's no conflict.
	_play("idle_%s" % _suffix())


func _suffix() -> String:
	if absf(_facing.x) > absf(_facing.y):
		return "side"
	return "down" if _facing.y >= 0 else "up"


func _play(anim_name: String) -> void:
	if animated_sprite == null:
		return
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		push_warning("FishingAnimationComponent: missing animation '%s'" % anim_name)
