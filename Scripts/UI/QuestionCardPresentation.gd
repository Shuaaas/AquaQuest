extends RefCounted
## Shared question-card presentation only; managers retain all game rules.


static func setup(screen: Control) -> void:
	screen.theme = screen.theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Keep glyph caches independent from the older pixel-font screens.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		screen.theme.default_font = font
	screen.resized.connect(func(): layout(screen))
	screen.get_node("%Panel").minimum_size_changed.connect(func(): layout.call_deferred(screen))
	layout.call_deferred(screen)


static func layout(screen) -> void:
	if not is_instance_valid(screen) or not screen.is_node_ready():
		return
	var bounds := Rect2(Vector2.ZERO, screen.size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var origin := Vector2(DisplayServer.window_get_position())
		var transform: Transform2D = screen.get_viewport().get_screen_transform().affine_inverse()
		var start := transform * (Vector2(safe.position) - origin)
		var end := transform * (Vector2(safe.end) - origin)
		bounds = bounds.intersection(Rect2(start, end - start))
	var padding := 12.0 if screen.size.x < 700 or screen.size.y < 450 else 28.0
	bounds = bounds.grow(-padding)
	var panel: Control = screen.get_node("%Panel")
	panel.size = bounds.size.min(Vector2(980, 740))
	panel.position = bounds.get_center() - panel.size / 2
	screen.get_node("%Title").add_theme_font_size_override(
		"font_size", 21 if screen.size.y < 450 or screen.size.x < 500 else 26
	)


static func clear_choices(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func add_choices(container: VBoxContainer, choices: Array, handler: Callable) -> void:
	clear_choices(container)
	for index in choices.size():
		var button := Button.new()
		var letter := String.chr(65 + index) if index < 26 else str(index + 1)
		button.text = "%s.  %s" % [letter, str(choices[index])]
		button.custom_minimum_size.y = 52
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(handler.bind(index))
		container.add_child(button)


static func focus_question(screen) -> void:
	if not is_instance_valid(screen) or not screen.visible:
		return
	var choices: VBoxContainer = screen.get_node("%ChoicesContainer")
	if choices.visible and choices.get_child_count() > 0:
		choices.get_child(0).grab_focus()
	# Focus must not scroll past a long question before the player reads it.
	screen.get_node("%ScrollContainer").set_deferred("scroll_vertical", 0)


static func show_image(screen: Control, path: String) -> void:
	var image: TextureRect = screen.get_node("%QuestionImage")
	var texture := (
		load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	)
	image.texture = texture
	image.visible = texture != null
