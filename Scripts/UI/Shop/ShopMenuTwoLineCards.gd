extends ShopMenu
class_name ShopMenuTwoLineCards

var _last_purchase_multiplier: int = -1


func _process(_delta: float) -> void:
	if not visible or _selected_shop_index < 0:
		_last_purchase_multiplier = _get_purchase_multiplier()
		return

	var current_multiplier := _get_purchase_multiplier()
	if current_multiplier == _last_purchase_multiplier:
		return
	_last_purchase_multiplier = current_multiplier
	_refresh_current_shop_detail()


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


func _show_shop_detail(shop_index: int) -> void:
	if shop_index < 0 or shop_index >= _shops.size():
		_show_shop_list()
		return

	_selected_shop_index = shop_index
	_last_purchase_multiplier = _get_purchase_multiplier()
	var shop := _shops[_selected_shop_index]
	title_label.text = _single_line_shop_name(shop)
	back_button.visible = true
	shop_list_view.visible = false
	shop_detail_view.visible = true
	shop_name_label.text = ""
	shop_name_label.visible = false
	description_label.text = shop.description
	_apply_shop_portrait(shop)
	_play_shop_bgm(shop)
	_setup_item_tabs(shop)
	_refresh_item_grid(shop)


func _create_item_card(entry: ShopItemData, credits: int) -> Control:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(124, 184)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.tooltip_text = entry.get_description()
	card_panel.add_theme_stylebox_override("panel", _create_item_card_style())
	card_panel.mouse_entered.connect(Callable(self, "_show_item_popup").bind(entry, card_panel))
	card_panel.mouse_exited.connect(_hide_item_popup)

	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 8.0
	card.offset_top = 12.0
	card.offset_right = -8.0
	card.offset_bottom = -8.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 6)
	card_panel.add_child(card)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = _load_entry_icon(entry)
	card.add_child(icon_rect)

	var name_marquee := MarqueeLabel.new()
	name_marquee.custom_minimum_size = Vector2(0, 34)
	name_marquee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_marquee.font_size = 13
	name_marquee.set_display_text(entry.get_display_name())
	card.add_child(name_marquee)

	var purchase_amount := _get_purchase_amount(entry)
	var total_price := entry.get_unit_price() * purchase_amount

	var price_label := Label.new()
	price_label.text = "%d C" % total_price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.add_theme_font_size_override("font_size", 14)
	card.add_child(price_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(0, 30)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.text = "%d個購入" % purchase_amount
	buy_button.tooltip_text = "現在の購入数: %d個 / Shift 10倍 / Ctrl 100倍" % purchase_amount
	buy_button.disabled = not entry.is_available or total_price > credits
	buy_button.add_theme_stylebox_override("normal", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("hover", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("pressed", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("focus", _create_purchase_button_style())
	buy_button.pressed.connect(Callable(self, "_on_buy_pressed").bind(entry))
	buy_button.mouse_entered.connect(Callable(self, "_show_item_popup").bind(entry, card_panel))
	buy_button.mouse_exited.connect(_hide_item_popup)
	card.add_child(buy_button)

	return card_panel


func _single_line_shop_name(shop: ShopData) -> String:
	if shop == null:
		return ""
	return shop.display_name.replace("\n", " ").strip_edges()
