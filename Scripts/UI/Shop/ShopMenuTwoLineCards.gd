extends ShopMenu
class_name ShopMenuTwoLineCards

signal shop_layout_invalidated(shop_id: StringName)
signal shop_database_layout_invalidated()

var _last_purchase_multiplier: int = -1
var _item_card_buttons: Dictionary = {}
var _item_card_price_labels: Dictionary = {}
var _shop_list_layout_built: bool = false
var _known_shop_cache_version: int = -1
var _current_tab_shop_key: String = ""
var _item_layout_cache: Dictionary = {}
var _current_item_layout_key: String = ""


func _process(_delta: float) -> void:
	if not visible or _selected_shop_index < 0:
		_last_purchase_multiplier = _get_purchase_multiplier()
		return

	var current_multiplier: int = _get_purchase_multiplier()
	if current_multiplier == _last_purchase_multiplier:
		return
	_last_purchase_multiplier = current_multiplier
	_refresh_purchase_states()


func _setup_item_popup() -> void:
	pass


func _show_item_popup(_entry: ShopItemData, _anchor: Control) -> void:
	pass


func _hide_item_popup() -> void:
	pass


func _reload_shops() -> void:
	_shops.clear()
	if shop_database != null:
		ShopRuntimeCache.prepare_database(shop_database)
		_shops = ShopRuntimeCache.get_shops(shop_database)

	var current_cache_version: int = ShopRuntimeCache.get_version()
	if _known_shop_cache_version >= 0 and current_cache_version != _known_shop_cache_version:
		_free_shop_list_layout()
		_free_all_item_layouts()
	_known_shop_cache_version = current_cache_version

	if _selected_shop_index >= _shops.size():
		_selected_shop_index = -1


func _show_shop_list() -> void:
	_hide_item_popup()
	_detach_current_item_grid_to_cache()
	_restore_previous_bgm_if_needed()
	_selected_shop_index = -1
	_current_shop_tab_index = 0
	title_label.text = "ショップ一覧"
	back_button.visible = false
	shop_list_view.visible = true
	shop_detail_view.visible = false

	if shop_database == null:
		detail_label.text = "ShopDatabase が未設定です。"
		return

	if _shops.is_empty():
		detail_label.text = "登録されたショップがありません。"
		return

	_ensure_shop_list_layout()
	detail_label.text = "行きたいお店を選んでください。"
	_clear_duplicated_shop_list_detail()


func _ensure_shop_list_layout() -> void:
	if _shop_list_layout_built and shop_list.get_child_count() > 0:
		return

	super._clear_shop_list()
	for index in range(_shops.size()):
		shop_list.add_child(_create_shop_button(_shops[index], index))
	_shop_list_layout_built = true


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
	button.add_theme_stylebox_override("hover", _create_shop_card_style(SHOP_CARD_HOVER_BORDER_WIDTH, true))
	button.add_theme_stylebox_override("pressed", _create_shop_card_style(SHOP_CARD_HOVER_BORDER_WIDTH, true))
	button.add_theme_stylebox_override("focus", _create_shop_card_style(SHOP_CARD_HOVER_BORDER_WIDTH, true))
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
	var shop: ShopData = _shops[_selected_shop_index]
	title_label.text = _single_line_shop_name(shop)
	back_button.visible = true
	shop_list_view.visible = false
	shop_detail_view.visible = true
	shop_name_label.text = ""
	shop_name_label.visible = false
	description_label.text = shop.description
	_apply_shop_portrait(shop)
	_play_shop_bgm(shop)
	_setup_item_tabs_if_needed(shop)
	_refresh_item_grid(shop)


func _setup_item_tabs_if_needed(shop: ShopData) -> void:
	var shop_key: String = ShopRuntimeCache.get_shop_cache_key(shop)
	if _current_tab_shop_key == shop_key and item_tab_bar.tab_count > 0:
		var tabs: Array[ShopTabData] = shop.get_tabs()
		if tabs.is_empty():
			item_tab_bar.visible = false
			_current_shop_tab_index = 0
			return
		item_tab_bar.visible = true
		_current_shop_tab_index = clampi(_current_shop_tab_index, 0, tabs.size() - 1)
		if item_tab_bar.current_tab != _current_shop_tab_index:
			item_tab_bar.current_tab = _current_shop_tab_index
		return

	_current_tab_shop_key = shop_key
	_setup_item_tabs(shop)


func _refresh_item_grid(shop: ShopData) -> void:
	_hide_item_popup()
	if shop == null:
		return

	var tab_id: StringName = _get_current_shop_tab_id(shop)
	var cache_key: String = ShopRuntimeCache.get_tab_cache_key(shop, tab_id)
	var credits: int = _get_wallet_credits()

	if cache_key == _current_item_layout_key and item_grid.get_child_count() > 0:
		_refresh_purchase_states()
		return

	var has_cached_layout: bool = _item_layout_cache.has(cache_key)
	_detach_current_item_grid_to_cache()
	_current_item_layout_key = cache_key

	if has_cached_layout:
		_attach_cached_item_cards(cache_key)
		_refresh_purchase_states()
		return

	var entries: Array[ShopItemData] = ShopRuntimeCache.get_items_for_shop_tab(shop, tab_id)
	if entries.is_empty():
		_item_layout_cache[cache_key] = []
		detail_label.text = "このタブの商品はまだありません。"
		return

	var cards: Array[Control] = []
	for entry in entries:
		var item_card: Control = _create_item_card(entry, credits)
		cards.append(item_card)
		item_grid.add_child(item_card)
	_item_layout_cache[cache_key] = cards

	detail_label.text = "所持クレジット: %d" % credits
	_apply_purchase_guide_to_detail_label()


func _load_entry_icon(entry: ShopItemData) -> Texture2D:
	return ShopRuntimeCache.get_icon_for_entry(entry)


func _create_item_card(entry: ShopItemData, credits: int) -> Control:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(0, 132)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.tooltip_text = ""
	card_panel.add_theme_stylebox_override("panel", _create_item_card_style())

	var card := HBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 10.0
	card.offset_top = 10.0
	card.offset_right = -10.0
	card.offset_bottom = -10.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 12)
	card_panel.add_child(card)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(112, 112)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = _load_entry_icon(entry)
	card.add_child(icon_rect)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_column.add_theme_constant_override("separation", 4)
	card.add_child(info_column)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(0, 42)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = entry.get_display_name()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 15)
	info_column.add_child(name_label)

	var description_label_card := Label.new()
	description_label_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label_card.text = entry.get_description()
	description_label_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label_card.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label_card.clip_text = true
	description_label_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label_card.add_theme_font_size_override("font_size", 11)
	info_column.add_child(description_label_card)

	var is_book: bool = entry.is_book_product()
	var is_owned_book: bool = is_book and _is_book_owned(entry)
	var purchase_amount: int = _get_purchase_amount(entry)
	var total_price: int = entry.get_unit_price() * purchase_amount

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(116, 0)
	action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_column.add_theme_constant_override("separation", 8)
	card.add_child(action_column)

	var price_label := Label.new()
	price_label.text = "%d C" % total_price
	price_label.custom_minimum_size = Vector2(0, 32)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.add_theme_font_size_override("font_size", 14)
	action_column.add_child(price_label)
	if is_owned_book:
		price_label.text = ""
		price_label.visible = false

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(0, 34)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.text = "%d個購入" % purchase_amount
	buy_button.tooltip_text = ""
	buy_button.disabled = not entry.is_available or total_price > credits
	if is_book:
		buy_button.text = "購入済み" if is_owned_book else "購入"
		buy_button.disabled = not entry.is_available or is_owned_book or total_price > credits
	buy_button.add_theme_stylebox_override("normal", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("hover", _create_purchase_button_style(PURCHASE_BUTTON_HOVER_BORDER_WIDTH, true))
	buy_button.add_theme_stylebox_override("pressed", _create_purchase_button_style(PURCHASE_BUTTON_HOVER_BORDER_WIDTH, true))
	buy_button.add_theme_stylebox_override("focus", _create_purchase_button_style(PURCHASE_BUTTON_HOVER_BORDER_WIDTH, true))
	buy_button.add_theme_stylebox_override("disabled", _create_purchase_button_style(PURCHASE_BUTTON_BORDER_WIDTH, false, true))
	buy_button.pressed.connect(Callable(self, "_on_buy_pressed").bind(entry))
	action_column.add_child(buy_button)

	var state_key: int = _get_entry_state_key(entry)
	_item_card_buttons[state_key] = buy_button
	_item_card_price_labels[state_key] = price_label
	_refresh_purchase_state_for_entry(entry, credits)

	return card_panel


func _on_buy_pressed(entry: ShopItemData) -> void:
	if entry == null:
		return
	if entry.is_book_product():
		_on_book_buy_pressed(entry)
		return
	_resolve_inventory_module()
	if _inventory_module == null:
		detail_label.text = "購入先のインベントリが見つかりません。"
		return

	var purchase_amount: int = _get_purchase_amount(entry)
	var total_price: int = entry.get_unit_price() * purchase_amount
	_is_purchase_refresh_suppressed = true
	var did_spend: bool = _spend_credits(total_price, entry)
	_is_purchase_refresh_suppressed = false
	if not did_spend:
		_refresh_purchase_states()
		detail_label.text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, _get_wallet_credits()]
		return

	if not _add_entry_to_inventory(entry, purchase_amount):
		_is_purchase_refresh_suppressed = true
		_refund_credits(total_price, entry)
		_is_purchase_refresh_suppressed = false
		_refresh_purchase_states()
		detail_label.text = "インベントリに空きがありません。購入を取り消しました。"
		return
	_refresh_purchase_states()
	detail_label.text = "購入しました: %s x%d" % [entry.get_display_name(), purchase_amount]


func _on_book_buy_pressed(entry: ShopItemData) -> void:
	var book: BookData = entry.get_book_data()
	if book == null:
		_refresh_purchase_states()
		detail_label.text = "書籍データが見つかりません。"
		return

	var library: Node = _resolve_book_library()
	if library == null or not library.has_method("add_book"):
		_refresh_purchase_states()
		detail_label.text = "書籍ライブラリが見つかりません。"
		return

	if _is_book_owned(entry):
		_refresh_purchase_states()
		detail_label.text = "購入済みです: %s" % entry.get_display_name()
		return

	var total_price: int = entry.get_unit_price()
	_is_purchase_refresh_suppressed = true
	var did_spend: bool = _spend_credits(total_price, entry)
	_is_purchase_refresh_suppressed = false
	if not did_spend:
		_refresh_purchase_states()
		detail_label.text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, _get_wallet_credits()]
		return

	_is_purchase_refresh_suppressed = true
	var did_add_book: bool = library.call("add_book", book) == true
	_is_purchase_refresh_suppressed = false
	if not did_add_book:
		_is_purchase_refresh_suppressed = true
		_refund_credits(total_price, entry)
		_is_purchase_refresh_suppressed = false
		_refresh_purchase_states()
		detail_label.text = "書籍の登録に失敗しました。購入を取り消しました。"
		return

	_refresh_purchase_states()
	detail_label.text = "電子書籍を購入しました: %s" % entry.get_display_name()


func _get_entry_state_key(entry: ShopItemData) -> int:
	if entry == null:
		return 0
	return entry.get_instance_id()


func _refresh_purchase_states() -> void:
	if _selected_shop_index < 0 or _selected_shop_index >= _shops.size():
		return

	var shop: ShopData = _shops[_selected_shop_index]
	var tab_id: StringName = _get_current_shop_tab_id(shop)
	var entries: Array[ShopItemData] = ShopRuntimeCache.get_items_for_shop_tab(shop, tab_id)
	var credits: int = _get_wallet_credits()
	for entry in entries:
		_refresh_purchase_state_for_entry(entry, credits)

	detail_label.text = "所持クレジット: %d" % credits
	_apply_purchase_guide_to_detail_label()


func _refresh_purchase_state_for_entry(entry: ShopItemData, credits: int) -> void:
	if entry == null:
		return

	var state_key: int = _get_entry_state_key(entry)
	var buy_button: Button = _item_card_buttons.get(state_key) as Button
	if buy_button == null or not is_instance_valid(buy_button):
		return

	var price_label: Label = _item_card_price_labels.get(state_key) as Label
	var is_book: bool = entry.is_book_product()
	var is_owned_book: bool = is_book and _is_book_owned(entry)
	var purchase_amount: int = _get_purchase_amount(entry)
	var total_price: int = entry.get_unit_price() * purchase_amount

	if price_label != null and is_instance_valid(price_label):
		price_label.text = "%d C" % total_price
		price_label.visible = true
		if is_owned_book:
			price_label.text = ""
			price_label.visible = false

	if is_book:
		buy_button.text = "購入済み" if is_owned_book else "購入"
		buy_button.disabled = not entry.is_available or is_owned_book or total_price > credits
		return

	buy_button.text = "%d個購入" % purchase_amount
	buy_button.disabled = not entry.is_available or total_price > credits


func invalidate_shop_layout(shop_id: StringName = &"") -> void:
	if shop_id == &"":
		ShopRuntimeCache.mark_cache_dirty()
		_reload_shops()
		_free_shop_list_layout()
		_free_all_item_layouts()
		shop_database_layout_invalidated.emit()
		return

	_free_shop_list_layout()
	_free_shop_item_layout(String(shop_id))
	shop_layout_invalidated.emit(shop_id)


func _attach_cached_item_cards(cache_key: String) -> void:
	var cards: Array[Control] = _get_cached_item_cards(cache_key)
	for card in cards:
		if card.get_parent() != item_grid:
			item_grid.add_child(card)


func _detach_current_item_grid_to_cache() -> void:
	if item_grid == null:
		return
	if item_grid.get_child_count() <= 0:
		return

	var cards: Array[Control] = []
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		if child is Control and is_instance_valid(child):
			cards.append(child as Control)

	if not _current_item_layout_key.is_empty():
		_item_layout_cache[_current_item_layout_key] = cards


func _get_cached_item_cards(cache_key: String) -> Array[Control]:
	var result: Array[Control] = []
	var cached_value: Variant = _item_layout_cache.get(cache_key, [])
	if not (cached_value is Array):
		return result
	for value in cached_value:
		if value is Control and is_instance_valid(value):
			result.append(value as Control)
	return result


func _clear_item_grid() -> void:
	_free_all_item_layouts()


func _free_shop_list_layout() -> void:
	_shop_list_layout_built = false
	super._clear_shop_list()


func _free_all_item_layouts() -> void:
	var freed_ids: Dictionary = {}
	for cached_value in _item_layout_cache.values():
		if not (cached_value is Array):
			continue
		for value in cached_value:
			if value is Control:
				_queue_free_control_once(value as Control, freed_ids)
	for child in item_grid.get_children():
		if child is Control:
			_queue_free_control_once(child as Control, freed_ids)
	_item_layout_cache = {}
	_item_card_buttons = {}
	_item_card_price_labels = {}
	_current_item_layout_key = ""
	_current_tab_shop_key = ""


func _free_shop_item_layout(shop_key: String) -> void:
	if shop_key.strip_edges().is_empty():
		_free_all_item_layouts()
		return

	var freed_ids: Dictionary = {}
	var key_prefix: String = "%s|" % shop_key
	var keys_to_remove: Array[String] = []
	for cache_key in _item_layout_cache.keys():
		var key_text: String = String(cache_key)
		if key_text.begins_with(key_prefix):
			keys_to_remove.append(key_text)

	for cache_key in keys_to_remove:
		var cards: Array[Control] = _get_cached_item_cards(cache_key)
		for card in cards:
			_queue_free_control_once(card, freed_ids)
		_item_layout_cache.erase(cache_key)
		if _current_item_layout_key == cache_key:
			_current_item_layout_key = ""

	if _current_tab_shop_key == shop_key:
		_current_tab_shop_key = ""
	_item_card_buttons = {}
	_item_card_price_labels = {}


func _queue_free_control_once(control: Control, freed_ids: Dictionary) -> void:
	if control == null or not is_instance_valid(control):
		return
	var instance_id: int = control.get_instance_id()
	if freed_ids.has(instance_id):
		return
	freed_ids[instance_id] = true
	var parent: Node = control.get_parent()
	if parent != null:
		parent.remove_child(control)
	control.queue_free()


func _apply_purchase_guide_to_detail_label() -> void:
	if detail_label == null:
		return
	var text := detail_label.text.strip_edges()
	if not text.begins_with("所持クレジット:"):
		return
	detail_label.text = "%s　購入数: 通常 / Shift 10倍 / Ctrl 100倍" % text


func _clear_duplicated_shop_list_detail() -> void:
	if detail_label == null:
		return
	var guide_text := ""
	if guide_label != null:
		guide_text = guide_label.text.strip_edges()
	var detail_text := detail_label.text.strip_edges()
	if detail_text == "利用したいお店を選んでください。" or detail_text == guide_text:
		detail_label.text = ""


func _single_line_shop_name(shop: ShopData) -> String:
	if shop == null:
		return ""
	return shop.display_name.replace("\n", " ").strip_edges()
