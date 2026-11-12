extends Control
class_name ToastUI
## Displays UIManager notifications without changing message, duration, or priority rules.
## A newer request replaces the previous message and its transition.

const EQUIPMENT_MESSAGES := [
	"You don't have a fishing rod yet.",
	"Equip your fishing rod first.",
	"You need a different rod for this spot.",
]
const TOP_INSET := 20.0
const MAX_WIDTH := 520.0

var _transition: Tween
var _showing_explanation := false
var _rest_y := TOP_INSET
var _slide_y := 0.0

@onready var panel: PanelContainer = %PanelContainer
@onready var scroll: ScrollContainer = %ScrollContainer
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
	EventBus.ui_notification_requested.connect(_on_notification_requested)
	EventBus.ui_explanation_requested.connect(_on_explanation_requested)
	%DismissButton.pressed.connect(_dismiss)
	resized.connect(_layout.call_deferred)
	toast_label.minimum_size_changed.connect(_layout.call_deferred)
	scroll.resized.connect(_layout.call_deferred)
	_layout.call_deferred()


func _on_notification_requested(message: String, duration: float) -> void:
	if not (visible and _showing_explanation):
		_show_toast(message, duration, false)


func _on_explanation_requested(message: String, duration: float) -> void:
	_show_toast(message, duration, true)


func _show_toast(message: String, duration: float, explanation: bool) -> void:
	# Input order follows sibling order, independently of the visual z-index.
	move_to_front()
	if _transition != null:
		_transition.kill()
	toast_label.text = message
	# The legacy signal has no category. Identify the existing equipment notices verbatim.
	var equipment := not explanation and message in EQUIPMENT_MESSAGES
	_showing_explanation = explanation
	%DismissButton.visible = explanation
	%CategoryLabel.text = "EQUIPMENT NOTICE" if equipment else "NOTICE"
	%NotificationIcon.text = "!" if equipment else "i"
	if explanation:
		%CategoryLabel.text = "EXPLANATION"
		%NotificationIcon.text = "?"
	scroll.scroll_vertical = 0

	panel.modulate.a = 0.0
	_slide_y = -4.0
	show()
	_layout()
	_layout.call_deferred()

	# Keep the fades inside the duration requested by the caller.
	var lifetime := maxf(duration, 0.001)
	var fade_in := minf(0.16, lifetime * 0.2)
	var fade_out := minf(0.18, lifetime * 0.2)
	_transition = create_tween()
	_transition.tween_property(panel, "modulate:a", 1.0, fade_in)
	_transition.parallel().tween_method(_set_slide, -4.0, 0.0, fade_in)
	_transition.tween_interval(lifetime - fade_in - fade_out)
	_transition.tween_property(panel, "modulate:a", 0.0, fade_out)
	_transition.tween_callback(hide)


func _input(event: InputEvent) -> void:
	if not (_showing_explanation and is_visible_in_tree()):
		return
	var mouse_click: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	)
	var screen_tap: bool = event is InputEventScreenTouch and event.pressed
	if mouse_click or screen_tap:
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	if _transition != null:
		_transition.kill()
	hide()


func _set_slide(offset: float) -> void:
	_slide_y = offset
	panel.position.y = _rest_y + offset


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
	var center := bounds.get_center().x
	var width := minf(MAX_WIDTH, bounds.size.x)
	_rest_y = bounds.position.y + TOP_INSET - 12.0

	# Fit between the top HUD controls when there is room for readable text.
	var hud := get_node_or_null("../GameplayHUD")
	var equipment := hud.get_node_or_null("%EquipmentStatus") as Control if hud else null
	var minimap := get_node_or_null("../MiniMapUI") as Control
	var dismiss_height := 50.0 if _showing_explanation else 0.0
	var half_gap := width * 0.5
	for control in [equipment, minimap]:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.end.x <= center:
			half_gap = minf(half_gap, center - rect.end.x - 8.0)
		elif rect.position.x >= center:
			half_gap = minf(half_gap, rect.position.x - center - 8.0)
		else:
			half_gap = 0.0
	if half_gap * 2.0 >= minf(200.0, width):
		width = floorf(half_gap * 2.0)
	else:
		# On very narrow screens the HUD can occupy the full top row.
		for control in [
			equipment,
			minimap,
			hud.get_node_or_null("%MenuButton") if hud else null,
			hud.get_node_or_null("%RegionBadge") if hud else null,
			hud.get_node_or_null("%CurrentQuest") if hud else null,
		]:
			if is_instance_valid(control) and control.is_visible_in_tree():
				_rest_y = maxf(_rest_y, control.get_global_rect().end.y + 10.0)
		_rest_y = minf(_rest_y, bounds.end.y - 68.0 - dismiss_height)

	var max_body := maxf(25.0, minf(124.0, bounds.end.y - _rest_y - 45.0 - dismiss_height))
	var message_height := toast_label.get_minimum_size().y
	scroll.custom_minimum_size.y = clampf(message_height, 25.0, max_body)
	panel.size = Vector2(width, 68.0)
	panel.position.x = roundf(center - panel.size.x / 2.0)
	_set_slide(_slide_y)
	# Only overflowing text accepts scrolling.
	scroll.mouse_filter = (
		Control.MOUSE_FILTER_PASS if message_height > max_body else Control.MOUSE_FILTER_IGNORE
	)
