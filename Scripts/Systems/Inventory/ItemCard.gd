extends RefCounted
## Reusable item presentation. No inventory or transaction mutations.


static func build(item_id: String, count: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	var header := HBoxContainer.new()
	card.add_child(header)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := ItemDatabase.get_icon_path(item_id)
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	header.add_child(icon)
	var name_label := Label.new()
	name_label.text = "%s x%d" % [ItemDatabase.get_display_name(item_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)
	add_text(card, ItemDatabase.get_description(item_id))
	add_text(
		card,
		(
			"Category: %s | Stack limit: %d"
			% [ItemDatabase.get_category(item_id).capitalize(), ItemDatabase.get_max_stack(item_id)]
		)
	)
	return card


static func add_text(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
