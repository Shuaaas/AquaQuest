extends Control
## Marker layer over the real region viewport. Positions use world coordinates.

const NAVIGATION := preload("res://Scripts/Systems/Map/MapNavigation.gd")
const COLORS := {
	"npc": Color("8ac6e0"),
	"fishing": Color("5c8ea5"),
	"shop": Color("a06131"),
	"exam": Color("cbe0e8"),
	"location": Color("ddccb8"),
	"exit": Color("ba9e6e"),
	"main_quest": Color("ba9e6e"),
	"mini_quest": Color("7a5388"),
}

var markers: Array = []
var player_position := Vector2.ZERO
@export_range(1.0, 2.0, 0.05) var player_arrow_scale := 1.25
var _display_angle := PI / 2
var _has_facing := false
var player_facing := Vector2.DOWN:
	set(value):
		if value.is_zero_approx():
			return
		player_facing = value
		if not _has_facing:
			_display_angle = player_facing.angle()
			_has_facing = true
var radius: float = 280.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_display_angle = lerp_angle(_display_angle, player_facing.angle(), 1.0 - exp(-18.0 * delta))
	queue_redraw()


func _draw() -> void:
	for marker in markers:
		var point := NAVIGATION.project_position(marker["position"], player_position, size, radius)
		var center := size * 0.5
		var limit := maxf(minf(size.x, size.y) * 0.5 - 10.0, 0.0)
		var offset := point - center
		var clamped := center + offset.limit_length(limit)
		var color: Color = COLORS.get(marker["kind"], Color("fffce6"))
		draw_rect(Rect2(clamped - Vector2(4, 4), Vector2(8, 8)), Color("160f09"))
		if offset.length() > limit:
			var direction := (point - size * 0.5).normalized()
			var side := direction.orthogonal()
			draw_colored_polygon(
				PackedVector2Array(
					[
						clamped + direction * 5,
						clamped - direction * 4 + side * 4,
						clamped - direction * 4 - side * 4
					]
				),
				color
			)
		elif marker["kind"] in ["main_quest", "mini_quest"]:
			draw_rect(Rect2(clamped - Vector2(2, 5), Vector2(4, 7)), color)
			draw_rect(Rect2(clamped + Vector2(-2, 4), Vector2(4, 3)), color)
		else:
			draw_rect(Rect2(clamped - Vector2(3, 3), Vector2(6, 6)), color)
	var center := size * 0.5
	draw_colored_polygon(player_indicator_points(), Color("fffce6"))
	draw_string(
		get_theme_default_font(),
		Vector2(center.x - 4, 16),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("fffce6")
	)


func player_indicator_points() -> PackedVector2Array:
	var center := size * 0.5
	var forward := Vector2.from_angle(_display_angle)
	var side := forward.orthogonal()
	return PackedVector2Array(
		[
			center + forward * (6 * player_arrow_scale),
			center + (-forward * 5 + side * 5) * player_arrow_scale,
			center + (-forward * 5 - side * 5) * player_arrow_scale
		]
	)
