extends GutTest
const TOAST := preload("res://Scene/UI/toast_ui.tscn")
const REWARD := preload("res://Scene/UI/ItemRewardToast.tscn")
var host: Control
var ui: ToastUI


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = Control.new()
	host.size = Vector2(1200, 760)
	add_child(host)
	ui = TOAST.instantiate()
	ui.name = "ToastUI"
	host.add_child(ui)


func after_each() -> void:
	GameManager.set_paused(false)
	host.free()
	await get_tree().process_frame


func settle() -> void:
	for frame in 12:
		await get_tree().process_frame


func test_existing_signal_keeps_message_and_short_notices_pass_input_through() -> void:
	UIManager.show_notification("Equip your fishing rod first.", 0.4)
	await settle()
	assert_eq(ui.toast_label.text, "Equip your fishing rod first.")
	assert_true(ui.visible)
	assert_eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(ui.get_node("%ScrollContainer").mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(get_tree().paused)
	assert_gte(ui.z_index, 60)
	await get_tree().create_timer(0.45).timeout
	assert_false(ui.visible)


func test_replacement_survives_previous_timer_and_uses_new_duration() -> void:
	ui._on_notification_requested("Earlier", 0.05)
	await get_tree().create_timer(0.02).timeout
	ui._on_notification_requested("New message", 0.25)
	await get_tree().create_timer(0.08).timeout
	assert_true(ui.visible)
	assert_eq(ui.toast_label.text, "New message")
	await get_tree().create_timer(0.2).timeout
	assert_false(ui.visible)


func test_notifications_expire_during_pause_without_releasing_it() -> void:
	GameManager.set_paused(true)
	ui._on_notification_requested("Paused notification", 0.08)
	assert_true(ui.can_process())
	await get_tree().create_timer(0.12).timeout
	assert_false(ui.visible)
	assert_true(get_tree().paused)


func test_long_messages_scroll_and_remain_bounded_at_supported_sizes() -> void:
	for dimensions in [Vector2(1200, 760), Vector2(720, 360), Vector2(390, 844)]:
		host.size = dimensions
		ui._on_notification_requested("Long feedback layout verification. ".repeat(80), 10)
		await settle()
		var panel: Control = ui.get_node("%PanelContainer")
		assert_true(Rect2(Vector2.ZERO, dimensions).encloses(panel.get_rect()), str(dimensions))
		assert_lt(panel.size.y, dimensions.y * 0.55)
		assert_almost_eq(panel.get_rect().get_center().x, dimensions.x / 2, 1.0)
		assert_almost_eq(panel.position.y, 12.0, 1.0)
		var scroll: ScrollContainer = ui.get_node("%ScrollContainer")
		assert_eq(scroll.mouse_filter, Control.MOUSE_FILTER_PASS)
		scroll.scroll_vertical = 200
		assert_gt(scroll.scroll_vertical, 0)
		ui._on_notification_requested("Short replacement", 10)
		await settle()
		assert_eq(scroll.scroll_vertical, 0)
		assert_eq(scroll.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_lte(panel.size.y, 140.0)


func test_acquisition_notice_waits_for_real_generic_toast() -> void:
	var reward := REWARD.instantiate()
	host.add_child(reward)
	ui._on_notification_requested("Transaction feedback", 0.08)
	reward._on_item_added("fish", 1)
	assert_false(reward.frame.visible)
	assert_eq(reward._pending.size(), 1)
	await get_tree().create_timer(0.12).timeout
	reward._pump()
	assert_false(ui.visible)
	assert_true(reward.frame.visible)


func test_new_notice_moves_above_later_overlay_controls_without_stealing_focus() -> void:
	var overlay := Button.new()
	overlay.text = "Existing overlay control"
	host.add_child(overlay)
	overlay.grab_focus()
	ui._on_notification_requested("Notification in front of the overlay", 1)
	assert_eq(ui.get_index(), host.get_child_count() - 1)
	assert_eq(get_viewport().gui_get_focus_owner(), overlay)
