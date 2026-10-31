extends Node
## Presentation-only skin. Does not read or change game/quest/save state.
## Added as a child of each UI root so dynamically generated controls inherit it.

const BASE_THEME := preload("res://Resources/UI/AquaQuestTheme.tres")
static var _shared_theme: Theme


static func shared_theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = BASE_THEME.duplicate(true)
		# Use Godot's bundled fallback font; no OS-specific font or download.
		var font := ThemeDB.fallback_font.duplicate() as FontFile
		if font != null:
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			font.hinting = TextServer.HINTING_NORMAL
			font.oversampling = 1.0
			_shared_theme.default_font = font
	return _shared_theme


func _ready() -> void:
	var root := get_parent() as Control
	if root == null:
		return
	root.theme = shared_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_watch(root)
	root.resized.connect(_update_spacing)
	_update_spacing()


func _watch(node: Node) -> void:
	if node is Viewport or node.has_meta("aqua_ui_styled"):
		return
	node.set_meta("aqua_ui_styled", true)
	if node is Button:
		var region_button := node.get_parent().name == &"RegionButtons"
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, 48 if region_button else 72)
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 48)
		if not node is OptionButton:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node.get_parent().name == &"FilterContainer":
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if node.name in ["Title", "TitleLabel", "SpeakerLabel", "SpotLabel"]:
			node.theme_type_variation = &"AquaHeading"
	if node is RichTextLabel and node.has_theme_font_size_override("normal_font_size"):
		var font_size: int = node.get_theme_font_size("normal_font_size")
		if font_size >= 22:
			node.add_theme_font_size_override("normal_font_size", 22)
	for child in node.get_children():
		_watch(child)
	node.child_entered_tree.connect(_watch)


func _update_spacing() -> void:
	var root := get_parent() as Control
	if root == null:
		return
	var padding := 8 if root.size.y < 500 else 12
	for margin in root.find_children("*", "MarginContainer", true, false):
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, padding)
	var dialogue_panel := root.get_node_or_null("%DialoguePanel") as Control
	if dialogue_panel != null and root.size.y > 0:
		var ratio := 0.84 if root.size.y < 500 else 0.65
		dialogue_panel.anchor_top = 1.0 - minf(420, root.size.y * ratio) / root.size.y
