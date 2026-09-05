extends Node
## Main
##
## Boot script for the persistent Main scene (CanvasLayer/HUD + RegionContainer).
## Its only job is to get the player into a starting region once the game
## begins - it doesn't own gameplay logic itself, just kicks off the first
## RegionManager.travel_to_region() call, same as any other trigger could
## later (a "New Game" button, a save-load continue, etc.).

## Which region a brand-new game starts in. Exposed here rather than
## hardcoded in RegionManager, since "where does a new game begin" is a
## Main-scene/boot concern, not something RegionManager should assume.
@export var starting_region_id: String = "region_1"


func _ready() -> void:
	RegionManager.unlock_region(starting_region_id)
	RegionManager.travel_to_region(starting_region_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		DialogueManager.choose(0)
