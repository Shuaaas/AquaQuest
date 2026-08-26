extends Area2D
class_name InteractionComponent
## InteractionComponent
##
## An Area2D "reach" zone that tracks every Interactable currently inside
## it and always targets the closest one. Knows nothing about what an
## Interactable actually does (NPC dialogue, chest loot, sign text) - it
## only calls `interact()` on whichever Interactable node it's tracking,
## keeping this component reusable for any future interactable type
## without modification (Open/Closed Principle).
##
## SETUP: give this Area2D a CollisionShape2D sized as the player's "reach",
## and set its collision_mask to the physics layer Interactables live on.

signal interactable_in_range_changed(interactable: Interactable)
signal interact_used(interactable: Interactable)

var _in_range: Array[Interactable] = []
var _closest: Interactable = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		_in_range.append(area)
		_update_closest()


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable and _in_range.has(area):
		_in_range.erase(area)
		_update_closest()


func _update_closest() -> void:
	var new_closest: Interactable = null
	var closest_distance := INF

	for interactable: Interactable in _in_range:
		if not is_instance_valid(interactable) or not interactable.enabled:
			continue
		var distance := global_position.distance_squared_to(interactable.global_position)
		if distance < closest_distance:
			closest_distance = distance
			new_closest = interactable

	if new_closest != _closest:
		_closest = new_closest
		interactable_in_range_changed.emit(_closest)


## Connect PlayerInputComponent.interact_pressed to this.
func try_interact() -> void:
	if _closest == null or not is_instance_valid(_closest):
		return
	_closest.interact(get_owner())
	interact_used.emit(_closest)
