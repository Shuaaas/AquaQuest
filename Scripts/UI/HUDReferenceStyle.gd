extends RefCounted
## The reference HUD palette and reusable chrome; other interfaces retain their theme.
const INK := Color("21160f")
const SHADOW := Color("302016")
const PANEL := Color("3a281c")
const INNER := Color("4a3020")
const WOOD := Color("76502f")
const LIGHT_WOOD := Color("987044")
const GOLD := Color("c6a66a")
const PARCHMENT := Color("e6d2ac")
const CREAM := Color("f0dec1")
const MUTED := Color("c8b18c")
const QUEST_GOLD := Color("d8b84f")
const PURPLE := Color("9560a2")
const GREEN := Color("718d43")
const SELECTED := Color("526e78")
const KNOT := preload("res://Assets/UI/HUDReference/knot.svg")
const LEAVES := preload("res://Assets/UI/HUDReference/leaves.svg")
const ICON_ROOT := "res://Assets/UI/HUDReference/"


static func panel(kind: String = "wood", margin: float = 12) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(ICON_ROOT + kind + ".svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 12)
		box.set_content_margin(side, margin)
	return box


static func skin_button(button: Button, plain: bool = false) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBox = StyleBoxEmpty.new() if plain else panel("button", 8)
		if box is StyleBoxTexture:
			box.modulate_color = Color(0.8, 0.8, 0.8) if state == "pressed" else Color.WHITE
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = SELECTED.lightened(0.35)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
