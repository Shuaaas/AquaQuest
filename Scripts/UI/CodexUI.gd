extends Control
## Persistent reader, following the Inventory/Exam UI scene pattern.
## Only CodexManager decides unlocks; this screen never changes quest state.

var _body_font_size := 20
var _sidebar_collapsed := false
var _module_ids: Array[String] = []
var _selected_module: String = ""
var _selected_lesson: String = ""
var _owns_pause := false
var _previous_focus: WeakRef
var _pictures: Array[TextureRect] = []
var _lesson_buttons: Dictionary = {}

@onready var module_list: OptionButton = %ModuleList
@onready var lesson_list: VBoxContainer = %LessonList
@onready var content: VBoxContainer = %Content
@onready var content_scroll: ScrollContainer = %ContentScroll
@onready var navigation: VBoxContainer = %Navigation
@onready var columns: BoxContainer = %Columns
@onready var lesson_scroll: ScrollContainer = %LessonScroll
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	theme = theme.duplicate()
	var bundled := ThemeDB.fallback_font as FontFile
	if bundled != null:
		# Copy source data only; duplicating a live font also copies its glyph cache.
		var font := FontFile.new()
		font.data = bundled.data
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		theme.default_font = font
	%SmallerText.pressed.connect(_change_text_size.bind(-2))
	%LargerText.pressed.connect(_change_text_size.bind(2))
	%SidebarButton.pressed.connect(_toggle_sidebar)
	%PreviousLesson.pressed.connect(_navigate_lesson.bind(-1))
	%NextLesson.pressed.connect(_navigate_lesson.bind(1))
	content_scroll.resized.connect(_update_reading_width)
	close_button.pressed.connect(close_codex)
	module_list.item_selected.connect(_on_module_selected)
	EventBus.codex_open_requested.connect(open_codex)
	EventBus.codex_progress_changed.connect(_refresh_progress)
	resized.connect(_update_layout)
	_update_layout()


func open_codex() -> bool:
	if visible:
		return true
	if not _can_open():
		UIManager.show_notification("Finish the current interaction before opening the Codex.")
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	GameManager.set_paused(true)
	_owns_pause = true
	show()
	_fill_modules()
	close_button.grab_focus()
	return true


func _can_open() -> bool:
	return (
		not get_tree().paused
		and not SaveManager.is_loading
		and not SceneLoader.is_loading()
		and not DialogueManager.is_active
		and not FishingManager.is_fishing()
		and GameManager.current_state in [GameManager.GameState.BOOT, GameManager.GameState.PLAYING]
	)


func close_codex() -> void:
	hide()
	_release_pause()
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		GameManager.set_paused(false)


func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_codex()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _fill_modules() -> void:
	module_list.clear()
	_module_ids.clear()
	for module in CodexManager.get_modules():
		_module_ids.append(module["module_id"])
		var number: String = module["module_id"].replace("_", " ").capitalize()
		module_list.add_item(number)
		module_list.set_item_tooltip(module_list.item_count - 1, module["module_title"])
	if _module_ids.is_empty():
		_clear_children(lesson_list)
		_clear_content()
		_add_text("Lessons are currently unavailable. Please try again later.")
		return
	var index := maxi(_module_ids.find(_selected_module), 0)
	module_list.select(index)
	show_module(_module_ids[index])


func _on_module_selected(index: int) -> void:
	if index >= 0 and index < _module_ids.size():
		show_module(_module_ids[index])


func show_module(module_id: String) -> void:
	_selected_module = module_id
	for module in CodexManager.get_modules():
		if module["module_id"] == module_id:
			%ModuleTitle.text = module["module_title"]
	var module_index := _module_ids.find(module_id)
	if module_index >= 0:
		module_list.select(module_index)
	_clear_children(lesson_list)
	_lesson_buttons.clear()
	var lessons := CodexManager.get_lessons(module_id)
	var selection := ""
	for lesson in lessons:
		var lesson_id: String = lesson["id"]
		var button := Button.new()
		var status := "Review" if CodexManager.is_lesson_unlocked(lesson_id) else "Locked"
		button.text = "[%s] %s" % [status, lesson["title"]]
		button.tooltip_text = button.text
		button.clip_text = false
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.custom_minimum_size.y = 48
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(show_lesson.bind(lesson_id))
		lesson_list.add_child(button)
		_lesson_buttons[lesson_id] = button
		if selection.is_empty() or lesson_id == _selected_lesson:
			selection = lesson_id
	if selection.is_empty():
		_selected_lesson = ""
		_clear_content()
		_add_text("No lessons are available for this module.")
	else:
		show_lesson(selection)


func show_lesson(lesson_id: String) -> void:
	_selected_lesson = lesson_id
	for button_id: String in _lesson_buttons:
		_lesson_buttons[button_id].set_pressed_no_signal(button_id == lesson_id)
	_clear_content()
	var lesson := CodexManager.get_lesson(lesson_id)
	if lesson.is_empty():
		_add_text("This lesson is unavailable.")
		return
	_update_lesson_navigation()
	_add_text(lesson["title"], 30)
	if not CodexManager.is_lesson_unlocked(lesson_id):
		_add_text(CodexManager.get_lock_message(lesson_id))
		return
	_add_text("Unlocked - available for review", 16)
	var overview := _study_card()
	_add_text("Lesson overview", 24, overview)
	_add_text(lesson["summary"], 20, overview)
	if (
		lesson.get("content_status", "")
		in ["partial_source_missing_supplement", "source_placeholder_only"]
	):
		_add_text("Some lecture material was not included in the course files.", 16)
	_render_key_concepts(lesson)
	var images_by_id: Dictionary = {}
	var shown: Dictionary = {}
	for picture in lesson.get("images", []):
		images_by_id[picture["id"]] = picture
	for section in lesson["sections"]:
		_add_text(section["heading"], 24)
		_add_text(section["content"])
		for image_id in section.get("image_ids", []):
			if images_by_id.has(image_id) and not shown.has(image_id):
				_add_picture(images_by_id[image_id])
				shown[image_id] = true
	_render_study_entries(lesson)
	for image_id: String in images_by_id:
		if not shown.has(image_id):
			_add_picture(images_by_id[image_id])
	_render_sources(lesson)
	_update_picture_sizes()


func _render_key_concepts(lesson: Dictionary) -> void:
	if not lesson.get("key_concepts", []).is_empty():
		_add_text("Key concepts", 24)
		for concept in lesson["key_concepts"]:
			var card := _study_card()
			_add_text(concept["term"], 22, card)
			_add_text(concept["definition"], 20, card)


func _render_study_entries(lesson: Dictionary) -> void:
	if not lesson.get("examples", []).is_empty():
		_add_text("Examples from the source", 24)
		for example in lesson["examples"]:
			var card := _study_card()
			_add_text(example["title"], 22, card)
			_add_text(example["content"], 20, card)
	for table in lesson.get("tables", []):
		_add_text(table["title"], 24)
		# A vertical representation remains readable without horizontal scrolling.
		for row in table["rows"]:
			var card := _study_card()
			for column in range(row.size()):
				_add_text("%s: %s" % [table["columns"][column], row[column]], 20, card)


func _render_sources(lesson: Dictionary) -> void:
	_add_text("Source pages: " + _page_text(lesson["source_pages"]), 16)
	if not lesson.get("references", []).is_empty():
		_add_text("References from the course material", 24)
		for reference in lesson["references"]:
			_add_text(reference["text"])


func _add_text(text: String, font_size: int = 20, parent: Node = null) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta("base_font_size", font_size)
	label.add_theme_font_size_override(
		"normal_font_size", maxi(16, font_size + _body_font_size - 20)
	)
	label.add_theme_constant_override("line_separation", 6)
	label.text = text
	(parent if parent != null else content).add_child(label)


func _add_picture(picture: Dictionary) -> void:
	var path: String = picture["path"]
	var texture: Texture2D
	# Check existence before loading so one missing asset never blocks the prose.
	if path.begins_with("res://Assets/Codex/") and ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	if texture == null:
		_add_text("Illustration unavailable: " + picture["caption"], 16)
		return
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	content.add_child(image)
	_pictures.append(image)
	_add_text(picture["caption"] + " (page " + _page_text(picture["source_pages"]) + ")", 16)


func _page_text(pages: Array) -> String:
	var parts := PackedStringArray()
	for page in pages:
		parts.append(str(int(page)))
	return ", ".join(parts)


func _clear_content() -> void:
	%PreviousLesson.disabled = true
	%NextLesson.disabled = true
	_pictures.clear()
	_clear_children(content)
	content_scroll.scroll_vertical = 0


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _refresh_progress() -> void:
	if visible:
		show_module(_selected_module)


func _study_card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "StudyCard"))
	content.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	return stack


func _change_text_size(amount: int) -> void:
	_body_font_size = clampi(_body_font_size + amount, 16, 28)
	for label in content.find_children("*", "RichTextLabel", true, false):
		label.add_theme_font_size_override(
			"normal_font_size",
			maxi(16, int(label.get_meta("base_font_size", 20)) + _body_font_size - 20)
		)
	%SmallerText.disabled = _body_font_size == 16
	%LargerText.disabled = _body_font_size == 28
	_update_reading_width.call_deferred()


func _toggle_sidebar() -> void:
	_sidebar_collapsed = not _sidebar_collapsed
	_update_layout()


func _navigate_lesson(step: int) -> void:
	var lessons := CodexManager.get_lessons(_selected_module)
	for index in lessons.size():
		if lessons[index]["id"] == _selected_lesson:
			var next := index + step
			if next >= 0 and next < lessons.size():
				show_lesson(lessons[next]["id"])
			return


func _update_lesson_navigation() -> void:
	var lessons := CodexManager.get_lessons(_selected_module)
	%PreviousLesson.disabled = true
	%NextLesson.disabled = true
	for index in lessons.size():
		if lessons[index]["id"] == _selected_lesson:
			%PreviousLesson.disabled = index == 0
			%NextLesson.disabled = index == lessons.size() - 1
			%Breadcrumb.text = (
				"%s / LESSON %d" % [_selected_module.replace("_", " ").to_upper(), index + 1]
			)
			return


func _update_layout() -> void:
	if not is_node_ready():
		return
	var narrow := size.x < 840 and size.x < size.y * 1.25
	columns.vertical = narrow
	%NavigationPanel.visible = not _sidebar_collapsed
	%SidebarButton.tooltip_text = (
		"Show lesson navigation" if _sidebar_collapsed else "Hide lesson navigation"
	)
	navigation.custom_minimum_size.x = 0 if narrow else minf(260, size.x * 0.28)
	%NavigationPanel.size_flags_vertical = Control.SIZE_FILL if narrow else Control.SIZE_EXPAND_FILL
	%ModuleTitle.visible = not narrow
	get_node("Margin/Panel/Book/Columns/NavigationPanel/Navigation/LessonsHeading").visible = not narrow
	lesson_scroll.custom_minimum_size.y = 96 if narrow else 0
	_update_reading_width.call_deferred()


func _update_reading_width() -> void:
	if not is_node_ready():
		return
	content.custom_minimum_size.x = maxf(100, minf(800, content_scroll.size.x - 24))
	_update_picture_sizes.call_deferred()


func _update_picture_sizes() -> void:
	for picture in _pictures:
		if is_instance_valid(picture) and picture.texture != null:
			var width := maxf(content.size.x, 200)
			var ratio := float(picture.texture.get_height()) / picture.texture.get_width()
			picture.custom_minimum_size.y = clampf(width * ratio, 120, 560)
