extends Camera2D
class_name PlayerCamera
## PlayerCamera
##
## Thin wrapper around Camera2D so Player.gd has one method to call
## (set_active) rather than reaching into Camera2D internals directly.
## In multiplayer, only the local authority's PlayerCamera should ever be
## active - remote players' cameras stay off so their instance doesn't
## fight for the viewport.
##
## Built-in Camera2D smoothing is used for follow behavior (configure
## `position_smoothing_speed` in the Inspector). `set_region_limits` is a
## forward-looking hook for RegionManager to call once region bounds data
## exists, so the camera doesn't show past the edge of a region.

func _ready() -> void:
	position_smoothing_enabled = true


func set_active(active: bool) -> void:
	enabled = active
	if active:
		make_current()


## Call once RegionManager exposes region bounds (Data/JSON/Regions), e.g.:
##   camera.set_region_limits(RegionManager.get_region_definition(id).get("bounds_rect"))
func set_region_limits(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)
