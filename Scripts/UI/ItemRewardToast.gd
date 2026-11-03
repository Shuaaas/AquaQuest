extends Control
## Queues actual item grants without replacing educational or transaction messages.

@export_range(0.1, 30.0, 0.1) var display_duration: float = 4.0
@export var generic_toast_path: NodePath = NodePath("../ToastUI")
var _pending: Array[Dictionary] = []
var _current: Dictionary = {}
var _generic_toast: Control
@onready var frame: Control = %RewardFrame
@onready var timer: Timer = %DisplayTimer
@onready var icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var description: Label = %Description
@onready var quantity: Label = %Quantity
@onready var rarity: Label = %Rarity


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	_generic_toast = get_node_or_null(generic_toast_path) as Control
	frame.hide()
	EventBus.item_added.connect(_on_item_added)
	EventBus.load_completed.connect(_on_load_completed)
	timer.timeout.connect(dismiss_current)
	%DismissButton.pressed.connect(dismiss_current)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if frame == null:
		return
	frame.size = Vector2(minf(440, size.x - 24), minf(320, size.y - 24))
	item_name.custom_minimum_size.x = minf(
		(
			item_name
			. get_theme_font("font")
			. get_string_size(
				item_name.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				item_name.get_theme_font_size("font_size")
			)
			. x
		),
		maxf(60, frame.size.x - 110)
	)
	frame.position = Vector2(
		floorf((size.x - frame.size.x) * 0.5), floorf(size.y - frame.size.y - 12)
	)


func _on_item_added(item_id: String, amount: int) -> void:
	if amount <= 0 or item_id.is_empty() or SaveManager.is_loading:
		return
	if not _pending.is_empty() and _pending.back().item_id == item_id:
		_pending.back().amount += amount
	else:
		_pending.append({"item_id": item_id, "amount": amount})
	_pump()


func _blocked() -> bool:
	return (
		get_tree().paused
		or DialogueManager.is_active
		or FishingManager.is_fishing()
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or MapManager.has_blocking_overlay()
		or (is_instance_valid(_generic_toast) and _generic_toast.is_visible_in_tree())
	)


func _process(_delta: float) -> void:
	_pump()


func _pump() -> void:
	if not is_node_ready():
		return
	if _blocked():
		frame.hide()
		timer.paused = true
		return
	if _current.is_empty():
		if _pending.is_empty():
			return
		_current = _pending.pop_front()
		_render_current()
		timer.start(display_duration)
	timer.paused = false
	frame.show()


func _render_current() -> void:
	var item_id: String = _current.item_id
	item_name.text = ItemDatabase.get_display_name(item_id)
	description.text = ItemDatabase.get_description(item_id)
	if description.text.is_empty():
		description.text = "Added to your inventory."
	quantity.text = "×%d" % int(_current.amount)
	rarity.text = (
		"%s %s"
		% [
			"★".repeat(ItemDatabase.get_rarity_stars(item_id)),
			ItemDatabase.get_rarity_name(item_id)
		]
	)
	frame.stars = ItemDatabase.get_rarity_stars(item_id)
	var path := ItemDatabase.get_icon_path(item_id)
	icon.texture = (
		load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	)
	%MissingIcon.visible = icon.texture == null
	_layout()
	%TextScroll.scroll_vertical = 0


func dismiss_current() -> void:
	timer.stop()
	_current = {}
	frame.hide()
	_pump()


func _on_load_completed(_slot: int) -> void:
	# Pending acquisition notices belong to the previous session, not the loaded save.
	_pending.clear()
	_current = {}
	timer.stop()
	frame.hide()
