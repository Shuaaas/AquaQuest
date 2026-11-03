extends Control
## A read-only journal. Quest managers retain all progression and reward decisions.
const DATA := preload("res://Scripts/UI/QuestJournalData.gd")
var _state := "active"
var _selected := ""
var _reading := false
var _owns_pause := false
var _previous_focus: WeakRef


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
		theme.default_font = font
	%CloseButton.pressed.connect(close_journal)
	%BackButton.pressed.connect(
		func():
			_reading = false
			_layout()
			_focus_list()
	)
	for state in ["active", "completed", "failed"]:
		get_node("%" + state.capitalize() + "Tab").pressed.connect(_change_tab.bind(state))
	for signal_name in [
		"quest_started",
		"quest_completed",
		"quest_failed",
		"quest_objectives_completed",
		"load_completed"
	]:
		EventBus.connect(signal_name, func(_value): _refresh_if_visible())
	EventBus.quest_updated.connect(func(_id, _progress): _refresh_if_visible())
	EventBus.difficulty_adjusted.connect(func(_tier, _reason): _refresh_if_visible())
	%Frame.minimum_size_changed.connect(_layout.call_deferred)
	resized.connect(_layout)
	_layout()


func open_journal(quest_id: String = "") -> bool:
	if visible:
		return true
	if (
		get_tree().paused
		or SaveManager.is_loading
		or SceneLoader.is_loading()
		or DialogueManager.is_active
		or FishingManager.is_fishing()
		or MapManager.has_blocking_overlay(self)
	):
		return false
	if not GameManager.current_state in [GameManager.GameState.BOOT, GameManager.GameState.PLAYING]:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_state = "active"
	_selected = quest_id
	_reading = not quest_id.is_empty()
	_owns_pause = true
	GameManager.set_paused(true)
	show()
	_refresh()
	_layout.call_deferred()
	%CloseButton.grab_focus()
	return true


func close_journal() -> void:
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
		close_journal()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _refresh_if_visible() -> void:
	if visible:
		_refresh()


func _change_tab(state: String) -> void:
	_state = state
	_selected = ""
	_reading = false
	_refresh()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _refresh() -> void:
	_clear(%QuestList)
	var ids := DATA.quest_ids(_state)
	if not _selected in ids:
		_selected = str(ids[0]) if not ids.is_empty() else ""
	for state in ["active", "completed", "failed"]:
		get_node("%" + state.capitalize() + "Tab").set_pressed_no_signal(_state == state)
	%FailedTab.visible = not DATA.quest_ids("failed").is_empty()
	for id in ids:
		var data := DATA.details(id)
		var button := Button.new()
		button.text = "%s\n%s" % [data.title, data.type]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 64
		button.toggle_mode = true
		button.button_pressed = id == _selected
		button.pressed.connect(_select.bind(id))
		%QuestList.add_child(button)
	if ids.is_empty():
		var label := Label.new()
		label.text = "No %s quests" % _state
		%QuestList.add_child(label)
	_fill_details()
	_layout()


func _select(id: String) -> void:
	_selected = id
	_reading = true
	_refresh()
	%DetailScroll.scroll_vertical = 0
	if size.x < 700:
		%BackButton.grab_focus()


func _text(value: String, font_size: int = 20) -> void:
	var label := RichTextLabel.new()
	label.text = value
	label.fit_content = true
	label.scroll_active = false
	label.bbcode_enabled = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	%Details.add_child(label)


func _fill_details() -> void:
	_clear(%Details)
	if _selected.is_empty():
		_text("No %s quests yet" % _state, 26)
		_text(
			(
				"Talk to an NPC to discover a quest."
				if _state == "active"
				else "Your quest records will appear here."
			)
		)
		return
	var data := DATA.details(_selected)
	_text(data.type.to_upper() + " · " + data.status, 16)
	_text(data.title, 28)
	_text(data.description)
	_text("OBJECTIVES", 16)
	for objective in data.objectives:
		_text(("✓ " if objective.complete else "◇ ") + objective.text + "\n" + objective.counter)
	if data.objectives.is_empty():
		_text("No objectives configured.")
	var bar := ProgressBar.new()
	bar.value = data.percent
	bar.custom_minimum_size.y = 18
	%Details.add_child(bar)
	_text("QUEST GIVER\n" + data.giver, 18)
	_text("LOCATION\n" + data.location, 18)
	_text("ITEM REWARD\n" + data.reward, 18)
	if data.status == "Ready to turn in":
		_text("Objectives complete. Return to the quest giver to finish this quest.")


func _focus_list() -> void:
	for child in %QuestList.get_children():
		if child is Button:
			child.grab_focus()
			return


func _layout() -> void:
	if not is_node_ready():
		return
	var margin := 12.0 if size.x < 700 else 32.0
	%Frame.position = Vector2.ONE * margin
	%Frame.size = (size - Vector2.ONE * margin * 2).min(Vector2(1100, 820))
	%Frame.position = (size - %Frame.size) / 2
	var compact := size.x < 700
	%Navigation.custom_minimum_size.x = 0 if compact else 230
	%Navigation.visible = not compact or not _reading
	%Paper.visible = not compact or _reading
	%BackButton.visible = compact
	%Footer.visible = size.y > 450
