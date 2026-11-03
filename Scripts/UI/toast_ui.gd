extends Control
class_name ToastUI
## Displays UIManager notifications without changing message, duration, or priority rules.
## A newer request restarts the same timer, replacing the previous message.

@onready var toast_label: Label = %ToastLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Avoid shared glyph-cache settings from the older pixel-style screens.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	%DisplayTimer.timeout.connect(hide)
	EventBus.ui_notification_requested.connect(_on_notification_requested)
	resized.connect(_layout)
	toast_label.minimum_size_changed.connect(_layout.call_deferred)
	%ScrollContainer.resized.connect(_layout.call_deferred)
	_layout.call_deferred()


func _on_notification_requested(message: String, duration: float) -> void:
	# Input order follows sibling order, independently of the visual z-index.
	move_to_front()
	toast_label.text = message
	%ScrollContainer.scroll_vertical = 0
	show()
	_layout()
	_layout.call_deferred()
	%DisplayTimer.start(maxf(duration, 0.001))


func _layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var origin := Vector2(DisplayServer.window_get_position())
		var transform := get_viewport().get_screen_transform().affine_inverse()
		var start := transform * (Vector2(safe.position) - origin)
		var end := transform * (Vector2(safe.end) - origin)
		bounds = bounds.intersection(Rect2(start, end - start))
	bounds = bounds.grow(-12)
	var panel: PanelContainer = %PanelContainer
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var scroll: ScrollContainer = %ScrollContainer
	var width := minf(640, bounds.size.x)
	panel.size.x = width
	# Cap the toast's reading area so long feedback never becomes a fullscreen panel.
	var max_body := maxf(24, minf(220, bounds.size.y * 0.42) - 70)
	var body_height := clampf(toast_label.get_minimum_size().y, 26, max_body)
	scroll.custom_minimum_size.y = body_height
	panel.reset_size()
	panel.size.x = width
	panel.position = Vector2(bounds.get_center().x - panel.size.x / 2, bounds.position.y)
	var overflowing := toast_label.get_minimum_size().y > body_height + 1
	# Only overflowing text accepts scrolling; ordinary notices never block gameplay taps.
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS if overflowing else Control.MOUSE_FILTER_IGNORE
