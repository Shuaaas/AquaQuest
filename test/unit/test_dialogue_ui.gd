extends GutTest
const DIALOGUE := preload("res://Scene/UI/dialogue_ui.tscn")
var ui: DialogueUI
var host: Control
var state: int


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	state = GameManager.current_state
	GameManager.current_state = GameManager.GameState.PLAYING
	host = Control.new()
	host.size = Vector2(1200, 760)
	add_child(host)
	ui = DIALOGUE.instantiate()
	host.add_child(ui)


func after_each() -> void:
	if DialogueManager.is_active:
		DialogueManager._end_dialogue()
	GameManager.set_paused(false)
	host.free()
	GameManager.current_state = state
	await get_tree().process_frame


func settle() -> void:
	for frame in 12:
		await get_tree().process_frame


func test_continue_uses_existing_flow_and_restores_focus() -> void:
	var previous := Button.new()
	previous.text = "Previous focus"
	host.add_child(previous)
	previous.grab_focus()
	DialogueManager.start_dialogue(
		"gut_dialogue",
		[{"speaker": "Guide", "text": "First line."}, {"speaker": "Guide", "text": "Second line."}]
	)
	await settle()
	assert_true(ui.visible)
	assert_eq(ui.dialogue_text_label.text, "First line.")
	assert_eq(get_viewport().gui_get_focus_owner(), ui.continue_button)
	assert_gte(ui.continue_button.size.y, 48.0)
	assert_false(get_tree().paused)
	ui.continue_button.pressed.emit()
	await settle()
	assert_eq(ui.dialogue_text_label.text, "Second line.")
	ui.continue_button.pressed.emit()
	await settle()
	assert_false(ui.visible)
	assert_false(DialogueManager.is_active)
	assert_eq(get_viewport().gui_get_focus_owner(), previous)


func test_branch_choices_keep_indices_and_have_touch_and_keyboard_focus() -> void:
	DialogueManager.start_dialogue_tree(
		"gut_choices",
		{
			"start":
			{
				"speaker": "Guide",
				"text": "Choose a response.",
				"choices":
				[
					{"text": "First response", "next": "first"},
					{"text": "Second response", "next": "second"}
				]
			},
			"first": {"text": "First branch."},
			"second": {"text": "Second branch."}
		},
		"start"
	)
	await settle()
	assert_false(ui.continue_button.visible)
	assert_eq(ui.choices_container.get_child_count(), 2)
	assert_eq(get_viewport().gui_get_focus_owner(), ui.choices_container.get_child(0))
	for button in ui.choices_container.get_children():
		assert_gte(button.size.y, 48.0)
	ui.choices_container.get_child(1).pressed.emit()
	await settle()
	assert_eq(ui.dialogue_text_label.text, "Second branch.")
	assert_eq(ui.choices_container.get_child_count(), 0)
	assert_true(ui.continue_button.visible)
	assert_false(ui.get_node("%Nameplate").visible)


func test_long_reading_resets_scroll_and_fits_supported_sizes() -> void:
	DialogueManager.start_dialogue(
		"gut_long",
		[
			{
				"speaker": "A guide with a long display name",
				"text": "A long line of dialogue for layout verification. ".repeat(70)
			},
			{"speaker": "Guide", "text": "Next line starts at the top."}
		]
	)
	for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844)]:
		host.size = dimensions
		await settle()
		var panel: Control = ui.get_node("%DialoguePanel")
		assert_true(Rect2(Vector2.ZERO, dimensions).encloses(panel.get_rect()), str(dimensions))
		assert_true(ui.continue_button.get_global_rect().end.y <= panel.get_global_rect().end.y)
		assert_gt(
			ui.get_node("%ScrollContainer").get_v_scroll_bar().max_value,
			ui.get_node("%ScrollContainer").size.y
		)
	ui.get_node("%ScrollContainer").scroll_vertical = 300
	ui.continue_button.pressed.emit()
	await settle()
	assert_eq(ui.get_node("%ScrollContainer").scroll_vertical, 0)
	assert_eq(ui.dialogue_text_label.text, "Next line starts at the top.")


func test_ended_dialogue_stays_hidden_after_deferred_finalization() -> void:
	DialogueManager.start_dialogue("gut_fast_end", [{"text": "One line."}])
	DialogueManager.advance()
	await settle()
	assert_false(ui.visible)
	assert_false(ui.continue_button.visible)


func test_controls_still_work_under_existing_foreign_pause() -> void:
	GameManager.set_paused(true)
	DialogueManager.start_dialogue("gut_paused", [{"text": "Paused dialogue."}])
	await settle()
	assert_true(ui.can_process())
	ui.continue_button.pressed.emit()
	assert_false(DialogueManager.is_active)
	assert_true(get_tree().paused)


func test_long_choice_dialogue_opens_at_top_instead_of_skipping_reading() -> void:
	DialogueManager.start_dialogue_tree(
		"gut_long_choices",
		{
			"start":
			{
				"speaker": "Guide",
				"text": "Long dialogue to read before responding. ".repeat(60),
				"choices": [{"text": "A response after reading", "next": ""}]
			}
		},
		"start"
	)
	await settle()
	assert_eq(ui.get_node("%ScrollContainer").scroll_vertical, 0)
	assert_eq(get_viewport().gui_get_focus_owner(), ui.choices_container.get_child(0))
