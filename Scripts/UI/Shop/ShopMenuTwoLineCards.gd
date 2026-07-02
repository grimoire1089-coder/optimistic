extends ShopMenu
class_name ShopMenuTwoLineCards


func _create_shop_button(shop: ShopData, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(164, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = ""
	button.tooltip_text = shop.description
	button.add_theme_stylebox_override("normal", _create_shop_card_style())
	button.add_theme_stylebox_override("hover", _create_shop_card_style())
	button.add_theme_stylebox_override("pressed", _create_shop_card_style())
	button.add_theme_stylebox_override("focus", _create_shop_card_style())
	button.pressed.connect(Callable(self, "_on_shop_selected").bind(index))

	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 10.0
	card.offset_top = 10.0
	card.offset_right = -10.0
	card.offset_bottom = -10.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 7)
	button.add_child(card)

	var sticker_rect := TextureRect.new()
	sticker_rect.custom_minimum_size = Vector2(124, 124)
	sticker_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sticker_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sticker_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sticker_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticker_rect.texture = _get_shop_card_texture(shop)
	card.add_child(sticker_rect)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(0, 54)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.text = shop.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 16)
	card.add_child(name_label)

	return button
