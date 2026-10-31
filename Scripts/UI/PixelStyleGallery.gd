extends Control
## Design-only gallery. Not connected to Main, gameplay signals or settings.

var _grid: GridContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	_label(layout, "AquaQuest / Pixel UI design gallery", true)
	_label(layout, "Component previews only. Unbuilt menus are not added to gameplay.")
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_grid)
	_card("Dialogue", "Teacher Ana", ["Continue"])
	_card("Inventory", "Fishing rod / quantity", ["All", "Codex"])
	_card("Quest Journal", "Quest title and objective progress", ["Quest entry"])
	_card("Fishing Question", "Educational question text", ["Answer option", "Hint"])
	_card("Fishing Result", "Catch result and learning feedback", ["Feedback style"])
	_card("Shop", "Item name / price in points", ["Buy", "Close"])
	_card("Main Menu", "AquaQuest", ["Continue", "New Game"])
	_card("Pause Menu", "Paused", ["Resume", "Settings"])
	var settings := _card("Settings", "Control styling preview", [])
	var checkbox := CheckBox.new()
	checkbox.text = "Sound"
	checkbox.button_pressed = true
	settings.add_child(checkbox)
	var slider := HSlider.new()
	slider.value = 65
	slider.custom_minimum_size.y = 48
	settings.add_child(slider)
	var hud := _card("HUD", "Quest progress", ["Map"])
	var progress := ProgressBar.new()
	progress.value = 65
	progress.custom_minimum_size.y = 28
	hud.add_child(progress)
	_card("Map and Mini Map", "Region / module / progress", ["R1", "Close"])
	_card("Performance Board", "Accuracy / completed quests", ["Close"])
	_card("Examination", "Question / results layout", ["Answer option", "Continue"])
	_card("Codex", "Module / lesson / source references", ["Review lesson"])
	resized.connect(_update_columns)
	_update_columns()


func _card(title: String, body: String, buttons: Array) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_label(box, title, true)
	_label(box, body)
	for text: String in buttons:
		var button := Button.new()
		button.text = text
		box.add_child(button)
	return box


func _label(parent: Node, text: String, heading: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if heading:
		label.theme_type_variation = &"AquaHeading"
	parent.add_child(label)


func _update_columns() -> void:
	if _grid != null:
		_grid.columns = clampi(int(size.x / 380), 1, 3)
