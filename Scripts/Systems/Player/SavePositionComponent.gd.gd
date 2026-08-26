extends Node
class_name SavePositionComponent
## SavePositionComponent
##
## Registers a single "player" section with the existing SaveManager
## autoload (see Autoload/SaveManager.gd - this does NOT duplicate that
## system, it plugs into it) and owns writing/restoring the player's
## world position + region. Other components (HealthComponent,
## StaminaComponent, etc.) that expose get_save_state()/apply_save_state()
## can register themselves here via `register_provider` so ALL player
## persistence flows through one save section instead of scattering
## SaveManager.register_section calls across every component.
##
## MULTIPLAYER NOTE: only the local player's instance should persist to
## disk. Player.gd only calls register_with_save_manager() when this
## instance is the local authority.

@export var body: CharacterBody2D

var _providers: Array[Node] = [] # each must implement get_save_state()/apply_save_state()


func register_provider(provider: Node) -> void:
	if provider.has_method("get_save_state") and provider.has_method("apply_save_state"):
		_providers.append(provider)
	else:
		push_warning("SavePositionComponent: '%s' is missing get_save_state/apply_save_state" % provider.name)


func register_with_save_manager() -> void:
	SaveManager.register_section("player", _get_data, _apply_data)


func _get_data() -> Dictionary:
	var data := {
		"position_x": body.global_position.x if body else 0.0,
		"position_y": body.global_position.y if body else 0.0,
		"region_id": RegionManager.current_region_id,
	}
	for provider: Node in _providers:
		data[provider.name] = provider.get_save_state()
	return data


func _apply_data(data: Dictionary) -> void:
	if body and data.has("position_x") and data.has("position_y"):
		body.global_position = Vector2(data["position_x"], data["position_y"])

	for provider: Node in _providers:
		if data.has(provider.name):
			provider.apply_save_state(data[provider.name])
