extends Area2D
class_name Interactable
## Interactable
##
## Base script for anything that can be interacted with: NPCs, chests,
## signs, quest triggers, fishing spots, etc. Attach this script directly
## for a simple interactable, or extend it in a subclass and override
## `interact()` for custom behavior. Must be on the "interactable" group
## (done automatically in _ready) and a physics layer InteractionComponent
## is configured to detect (see README_PLAYER_SYSTEM.md).

signal interacted(interactor: Node)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true


func _ready() -> void:
	add_to_group("interactable")


## Called by InteractionComponent when the player triggers interact input
## while this is the closest interactable in range. Override in a subclass
## for custom behavior, or just connect to `interacted` and leave this as-is.
func interact(interactor: Node) -> void:
	if not enabled:
		return
	interacted.emit(interactor)


func get_prompt_text() -> String:
	return prompt_text
