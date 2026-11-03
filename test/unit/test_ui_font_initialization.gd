extends GutTest
## Warming the fallback font must not seed a screen with its runtime glyph cache.

func test_interfaces_start_with_independent_font_caches() -> void:
	var bundled := ThemeDB.fallback_font as FontFile
	bundled.get_string_size("Warm fallback cache", HORIZONTAL_ALIGNMENT_LEFT, -1, 57)
	for path in [
		"res://Scene/UI/shop_ui.tscn",
		"res://Scene/UI/inventory_ui.tscn",
		"res://Scene/UI/CodexUI.tscn",
		"res://Scene/UI/dialogue_ui.tscn",
		"res://Scene/UI/QuestJournalUI.tscn",
		"res://Scene/UI/WorldMapUI.tscn",
	]:
		var ui = load(path).instantiate()
		add_child_autofree(ui)
		var font := ui.theme.default_font as FontFile
		assert_not_null(font, path)
		if font != null:
			assert_eq(font.data, bundled.data, path)
			assert_false(font.get_size_cache_list(0).has(Vector2i(57, 0)), path)