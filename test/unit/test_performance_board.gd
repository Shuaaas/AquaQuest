extends GutTest

const BOARD := preload("res://Scene/UI/performance_board.tscn")


func test_aqpi_stays_empty_until_a_quest_has_a_score() -> void:
	var saved := PerformanceTracker._get_save_data().duplicate(true)
	PerformanceTracker._apply_save_data({"total_questions_answered": 16})
	var board := BOARD.instantiate()
	add_child_autofree(board)
	assert_eq(board.aqpi_label.text, "—")
	board.hide()
	PerformanceTracker.quest_aqpi_scores["test_quest"] = 0.875
	PerformanceTracker.latest_scored_quest_id = "test_quest"
	board.show()
	assert_eq(board.aqpi_label.text, "87.5")
	PerformanceTracker._apply_save_data(saved)


func test_board_can_start_visible_without_accessing_unready_labels() -> void:
	var board := BOARD.instantiate()
	assert_true(board.visible)
	# Reproduce the startup notification explicitly before @onready runs.
	board._notification(CanvasItem.NOTIFICATION_VISIBILITY_CHANGED)
	add_child_autofree(board)
	assert_true(board.is_node_ready())
	assert_not_null(board.accuracy_label)
	assert_false(board.accuracy_label.text.is_empty())
	assert_string_contains(board.points_label.text, "Earned:")


func test_ready_board_refreshes_when_reopened() -> void:
	var board := BOARD.instantiate()
	board.hide()
	add_child_autofree(board)
	board.points_label.text = "stale display"
	board.show()
	assert_string_contains(board.points_label.text, "Earned:")
	assert_eq(board.get_node("%PointsValue").text, str(FishingManager.get_points()))
	board.get_node("%CloseButton").pressed.emit()
	assert_false(board.visible)


func test_summary_uses_actual_tracker_values_without_changing_them() -> void:
	var board := BOARD.instantiate()
	add_child_autofree(board)
	var total := PerformanceTracker.total_questions_answered
	var points := FishingManager.get_points()
	board._populate()
	assert_eq(board.accuracy_label.text, "%d%%" % int(PerformanceTracker.get_accuracy() * 100))
	assert_eq(board.get_node("%AccuracyProgress").value, PerformanceTracker.get_accuracy() * 100)
	assert_eq(board.correct_label.text, str(PerformanceTracker.total_correct))
	assert_eq(board.get_node("%PointsValue").text, str(points))
	assert_eq(PerformanceTracker.total_questions_answered, total)
	assert_eq(FishingManager.get_points(), points)


func test_reopen_does_not_duplicate_rows_or_lose_empty_states() -> void:
	var board := BOARD.instantiate()
	add_child_autofree(board)
	var count: int = board.region_container.get_child_count()
	for i in 3:
		board.hide()
		board.show()
		assert_eq(board.region_container.get_child_count(), count)
		assert_gt(board.exam_container.get_child_count(), 0)
		assert_gt(board.quest_container.get_child_count(), 0)


func test_small_and_large_layouts_keep_close_reachable_and_content_scrollable() -> void:
	var holder := Control.new()
	add_child_autofree(holder)
	var board := BOARD.instantiate()
	holder.add_child(board)
	for resolution in [Vector2(390,844), Vector2(600,900), Vector2(856,428), Vector2(1280,720)]:
		holder.size = resolution
		for i in 5:
			await get_tree().process_frame
		assert_true(Rect2(Vector2.ZERO,resolution).encloses(board.close_button.get_global_rect()), str(resolution))
		assert_eq(board.get_node("%Cards").columns, 1 if resolution.x < 440 else 2)
		var scroll: ScrollContainer = board.get_node("%ScrollContainer")
		assert_gt(scroll.size.y, 40.0)
		assert_lte(scroll.get_h_scroll_bar().max_value, scroll.size.x + 1)


func test_board_matches_newer_ui_font_and_wood_borders() -> void:
	var board := BOARD.instantiate()
	add_child_autofree(board)
	var font := board.theme.default_font as FontFile
	assert_not_null(font)
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_GRAY)
	var frame := board.get_node("Margin/Panel").get_theme_stylebox("panel") as StyleBoxTexture
	assert_eq(frame.texture.resource_path, "res://Assets/UI/HUDReference/wood.svg")
	assert_eq(frame.texture_margin_left, 12.0)
	var button := board.close_button.get_theme_stylebox("normal") as StyleBoxTexture
	assert_eq(button.texture.resource_path, "res://Assets/UI/HUDReference/button.svg")
