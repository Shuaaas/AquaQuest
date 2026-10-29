extends GutTest

const CODEX_PATH := "res://Resources/Codex/"


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Cannot open " + path)
	if file == null:
		return {}
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	file.close()
	assert_eq(result, OK, "Invalid JSON: " + path)
	assert_true(parser.data is Dictionary, "Expected an object: " + path)
	if result != OK or not parser.data is Dictionary:
		return {}
	return parser.data


func test_index_matches_modules_and_unique_lesson_ids() -> void:
	var index := _read_json(CODEX_PATH + "index.json")
	var seen_ids: Dictionary = {}
	for entry in index.get("modules", []):
		var module_data := _read_json(entry["path"])
		assert_eq(module_data.get("module_id"), entry["id"])
		assert_eq(module_data.get("module_title"), entry["title"])
		var lessons: Array = module_data.get("lessons", [])
		assert_eq(lessons.size(), entry["lessons"].size())
		for lesson_index in range(lessons.size()):
			var lesson: Dictionary = lessons[lesson_index]
			var lesson_id: String = lesson["id"]
			assert_false(seen_ids.has(lesson_id), "Duplicate lesson: " + lesson_id)
			seen_ids[lesson_id] = true
			assert_eq(lesson_id, entry["lessons"][lesson_index]["id"])
			assert_eq(lesson["module_id"], entry["id"])
			assert_eq(lesson["unlock_requirement"], {"type": "quest", "id": ""})
			assert_false(lesson.has("unlocked"), "Unlocks belong to progression state")
			assert_false(lesson["sections"].is_empty())
			for page_number in lesson["source_pages"]:
				assert_between(int(page_number), 1, int(module_data["source"]["page_count"]))


func test_all_lesson_images_are_supplied_and_decodable() -> void:
	var manifest := _read_json(CODEX_PATH + "asset_manifest.json")
	var assets_by_id: Dictionary = {}
	for asset in manifest.get("assets", []):
		assert_false(assets_by_id.has(asset["id"]), "Duplicate asset ID")
		assets_by_id[asset["id"]] = asset
		assert_true(FileAccess.file_exists(asset["path"]), "Missing " + asset["path"])
		var image := load(asset["path"]) as Texture2D
		assert_not_null(image, "Cannot decode " + asset["path"])
		if image != null:
			assert_eq(image.get_width(), int(asset["pixel_size"][0]))
			assert_eq(image.get_height(), int(asset["pixel_size"][1]))
	var index := _read_json(CODEX_PATH + "index.json")
	for entry in index.get("modules", []):
		var module_data := _read_json(entry["path"])
		for lesson in module_data.get("lessons", []):
			var lesson_images: Dictionary = {}
			for image in lesson["images"]:
				assert_true(assets_by_id.has(image["id"]), "Image missing from manifest")
				if assets_by_id.has(image["id"]):
					assert_eq(image["path"], assets_by_id[image["id"]]["path"])
				lesson_images[image["id"]] = true
			for section in lesson["sections"]:
				for image_id in section["image_ids"]:
					assert_true(lesson_images.has(image_id), "Section image missing from lesson")


func test_page_coverage_accounts_for_every_source_page_once() -> void:
	var coverage := _read_json(CODEX_PATH + "page_coverage.json")
	var index := _read_json(CODEX_PATH + "index.json")
	var seen_pages: Dictionary = {}
	for page in coverage.get("pages", []):
		var page_key := "%s:%d" % [page["module_id"], page["page"]]
		assert_false(seen_pages.has(page_key), "Duplicate coverage entry")
		seen_pages[page_key] = true
		assert_false(page["roles"].is_empty())
	for entry in index.get("modules", []):
		for page_number in range(1, int(entry["source_page_count"]) + 1):
			var page_key := "%s:%d" % [entry["id"], page_number]
			assert_true(seen_pages.has(page_key), "Unaccounted source page: " + page_key)
	assert_eq(seen_pages.size(), int(coverage["page_count"]))
