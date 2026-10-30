extends Control
## Marker layer over the real region viewport. Positions use world coordinates.

const NAVIGATION := preload("res://Scripts/Systems/Map/MapNavigation.gd")
const COLORS := {
	"npc": Color("71e1e3"),
	"fishing": Color("65aff4"),
	"shop": Color("e9a46f"),
	"exam": Color("a7dc8a"),
	"location": Color("d8dacb"),
	"exit": Color("83cdb2"),
	"main_quest": Color("ffdb70"),
	"mini_quest": Color("d2a5ff"),
}

var markers: Array = []
var player_position := Vector2.ZERO
var radius: float = 280.0


func _draw() -> void:
	for marker in markers:
		var point := NAVIGATION.project_position(marker["position"], player_position, size, radius)
		var limit := Rect2(Vector2(9, 9), size - Vector2(18, 18))
		var clamped := point.clamp(limit.position, limit.end)
		var color: Color = COLORS.get(marker["kind"], Color.WHITE)
		draw_rect(Rect2(clamped - Vector2(4, 4), Vector2(8, 8)), Color("10202c"))
		if not limit.has_point(point):
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
	draw_colored_polygon(
		PackedVector2Array(
			[center + Vector2(0, -6), center + Vector2(-5, 5), center + Vector2(5, 5)]
		),
		Color.WHITE
	)
	draw_string(
		get_theme_default_font(),
		Vector2(5, 15),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)
