extends Button

@export var inventory_path: NodePath


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(
		func():
			var inventory = get_node_or_null(inventory_path)
			if inventory != null:
				inventory.open_inventory()
	)


func _process(_delta: float) -> void:
	visible = (
		not get_tree().paused and not DialogueManager.is_active and not FishingManager.is_fishing()
	)
	for overlay in get_tree().get_nodes_in_group("gameplay_overlay"):
		if overlay is Control and overlay.is_visible_in_tree():
			visible = false
			break
