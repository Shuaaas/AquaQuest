extends CharacterBody2D
class_name Player
## Player (composition root)
##
## This script does NOT implement movement, animation, or interaction -
## each of those lives in its own reusable component script. Player.gd's
## only job is to:
##   1. Resolve references to child components via scene-unique names (%Name)
##      instead of hardcoded get_node("path/to/node") strings.
##   2. Wire components together with signals (mediator pattern) so no
##      component needs to know another component exists.
##   3. Handle multiplayer authority gating.
##
## Every child component below must have "Access as Unique Name" enabled
## in the editor (right-click the node > Access as Unique Name) with the
## exact names referenced here. See README_PLAYER_SYSTEM.md for the full
## scene tree and setup steps.
##
## NOTE: Health and Stamina components were removed from this system on
## request. Running is no longer gated by anything - MovementComponent's
## `_can_run` simply stays at its default `true`. If stamina-gated running
## is wanted again later, HealthComponent/StaminaComponent can be
## reintroduced as optional child components without touching this file's
## other wiring - see MovementComponent.set_can_run().

## Multiplayer peer id that owns this instance. Defaults to 1 (singleplayer
## / offline). Set by whatever spawns the player over the network.
@export var player_id: int = 1

@onready var input: PlayerInputComponent = %InputComponent
@onready var movement: MovementComponent = %MovementComponent
@onready var animation_component: PlayerAnimationComponent = %AnimationComponent
@onready var interaction: InteractionComponent = %InteractionComponent
@onready var camera: PlayerCamera = %PlayerCamera
@onready var spawn: SpawnPointComponent = %SpawnComponent
@onready var persistence: SavePositionComponent = %PersistenceComponent
@onready var fishing_rod: FishingRodComponent = %FishingRodComponent
@onready var fishing_animation: FishingAnimationComponent = %FishingAnimationComponent


func _ready() -> void:
	InventoryManager.add_item("fishing_rod", 1)
	print("Rod count: ", InventoryManager.get_item_count("fishing_rod"))
	movement.body = self
	persistence.body = self
	persistence.register_provider(fishing_rod)

	var is_local_authority := _configure_multiplayer_authority()
	_wire_signals()

	if is_local_authority:
		persistence.register_with_save_manager()

	spawn.resolve_and_place(self)


## Returns true if this instance is the one the local player controls.
func _configure_multiplayer_authority() -> bool:
	var is_local := true

	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(player_id)
		is_local = is_multiplayer_authority()

	# Remote players (in a future networked build) get no local input and
	# no active camera - their MovementComponent instead reacts to synced
	# state via a MultiplayerSynchronizer once actual netcode is added.
	input.set_active(is_local)
	camera.set_active(is_local)

	return is_local


func _wire_signals() -> void:
	# Input -> Movement
	input.move_input_changed.connect(movement.set_move_input)
	input.run_input_toggled.connect(movement.set_run_input)
	input.interact_pressed.connect(interaction.try_interact)
	input.toggle_rod_pressed.connect(fishing_rod.toggle)

	# Movement -> Animation
	movement.direction_changed.connect(animation_component.on_direction_changed)
	movement.started_moving.connect(animation_component.on_started_moving)
	movement.stopped_moving.connect(animation_component.on_stopped_moving)
	movement.running_state_changed.connect(animation_component.on_running_state_changed)

	# Movement -> FishingAnimation (facing only - flow signals are self-wired
	# via EventBus directly inside FishingAnimationComponent, see its own
	# class doc for why this one component is the exception to the mediator
	# pattern used everywhere else)
	movement.direction_changed.connect(fishing_animation.on_direction_changed)

	# FishingRod -> Animation (equip-aware animation variants, see PlayerAnimationComponent)
	fishing_rod.equipped_changed.connect(_on_rod_equipped_changed)

	# Interaction -> global EventBus (Player.gd is the one place allowed to
	# relay a local component signal onto the global bus, so InteractionComponent
	# itself stays decoupled from EventBus and reusable for non-player owners)
	interaction.interactable_in_range_changed.connect(_on_interactable_focus_changed)


func _on_rod_equipped_changed(is_equipped: bool) -> void:
	animation_component.on_equipment_changed(FishingRodComponent.ROD_ITEM_ID if is_equipped else "")


func _on_interactable_focus_changed(interactable: Interactable) -> void:
	var prompt := interactable.get_prompt_text() if interactable != null else ""
	EventBus.interactable_focus_changed.emit(prompt)
