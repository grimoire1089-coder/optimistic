extends PanelContainer
class_name ShopMenu

@export var shop_database: ShopDatabase
@export var actor_path: NodePath = NodePath("../../Robin")
@export var inventory_module_child_name: StringName = &"RobinInventoryModule"

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var back_button: Button = $MarginContainer/Rows/Header/BackButton
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var shop_list_view: VBoxContainer = $MarginContainer/Rows/ShopListView
@onready var guide_label: Label = $MarginContainer/Rows/ShopListView/GuideLabel
@onready var shop_list: GridContainer = $MarginContainer/Rows/ShopListView/ShopListScroll/ShopList
@onready var shop_detail_view: BoxContainer = $MarginContainer/Rows/ShopDetailView
@onready var portrait_rect: TextureRect = $MarginContainer/Rows/ShopDetailView/OwnerFrame/Portrait
@onready var shop_name_label: Label = $MarginContainer/Rows/ShopDetailView/ShopContent/ShopInfo/ShopNameLabel
@onready var description_label: Label = $MarginContainer/Rows/ShopDetailView/ShopContent/ShopInfo/DescriptionLabel
@onready var item_tab_bar: TabBar = $MarginContainer/Rows/ShopDetailView/ShopContent/ItemTabBar
@onready var item_grid: GridContainer = $MarginContainer/Rows/ShopDetailView/ShopContent/ItemScroll/ItemGrid
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _inventory_module: RobinInventoryModule
var _shops: Array[ShopData] = []
var _selected_shop_index: int = -1
var _current_shop_tab_index: int = 0
var _is_setting_item_tabs: bool = false
var _previous_bgm: AudioStream
var _previous_bgm_position: float = 0.0
var _has_previous_bgm: bool = false
var _active_shop_bgm: AudioStream
var _item_popup: PopupPanel
var _item_popup_name_label: Label
var _item_popup_description_label: Label
var _item_popup_price_label: Label


func _ready() -> void:
	visible = false
	add_to_group(&"shop_menu")
	back_button.text = "戻る"
	close_button.text = "X"
	guide_label.text = "行きたいお店を選んでください。"
	back_button.pressed.connect(_on_back_pressed)
	close_button.pressed.connect(close_menu)
	item_tab_bar.tab_changed.connect(_on_item_tab_changed)
	_setup_item_popup()
	_connect_wallet_signal()
	_resolve_inventory_module()
	_reload_shops()
	_show_shop_list()


func open_menu() -> void:
	visible = true
	_resolve_inventory_module()
	_reload_shops()
	_show_shop_list()


func close_menu() -> void:
	_hide_item_popup()
	_restore_previous_bgm_if_needed()
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _connect_wallet_signal() -> void:
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null:
		return
	var callable := Callable(self, "_on_wallet_balance_changed")
	if not wallet.is_connected("balance_changed", callable):
		wallet.connect("balance_changed", callable)


func _resolve_inventory_module() -> void:
	if _inventory_module != null and is_instance_valid(_inventory_module):
		return

	var actor := get_node_or_null(actor_path)
	if actor == null:
		push_warning("ショップ用の購入先アクターが見つかりません: %s" % actor_path)
		return

	if actor.has_method("get_inventory_module"):
		_inventory_module = actor.call("get_inventory_module") as RobinInventoryModule
	else:
		_inventory_module = actor.get_node_or_null(NodePath(String(inventory_module_child_name))) as RobinInventoryModule

	if _inventory_module == null:
		push_warning("ショップ用のインベントリモジュールが見つかりません。")


func _reload_shops() -> void:
	_shops.clear()
	if shop_database != null:
		_shops = shop_database.get_shops()
	if _selected_shop_index >= _shops.size():
		_selected_shop_index = -1


func _show_shop_list() -> void:
	_hide_item_popup()
	_restore_previous_bgm_if_needed()
	_selected_shop_index = -1
	_current_shop_tab_index = 0
	title_label.text = "ショップ一覧"
	back_button.visible = false
	shop_list_view.visible = true
	shop_detail_view.visible = false
	_clear_shop_list()
	_clear_item_grid()

	if shop_database == null:
		detail_label.text = "ShopDatabase が未設定です。"
		return

	if _shops.is_empty():
		detail_label.text = "登録されたショップがありません。"
		return

	for index in range(_shops.size()):
		shop_list.add_child(_create_shop_button(_shops[index], index))

	detail_label.text = "行きたいお店を選んでください。"


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
	name_label.custom_minimum_size = Vector2(0, 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = shop.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 16)
	card.add_child(name_label)

	var description_label_card := Label.new()
	description_label_card.text = shop.description
	description_label_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label_card.clip_text = true
	description_label_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label_card.add_theme_font_size_override("font_size", 10)
	card.add_child(description_label_card)

	return button


func _get_shop_card_texture(shop: ShopData) -> Texture2D:
	if shop == null:
		return null
	if shop.sticker != null:
		return shop.sticker
	return shop.portrait


func _create_shop_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 1.0)
	style.border_color = Color(0.14, 0.8, 0.95, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _show_shop_detail(shop_index: int) -> void:
	if shop_index < 0 or shop_index >= _shops.size():
		_show_shop_list()
		return

	_selected_shop_index = shop_index
	var shop := _shops[_selected_shop_index]
	title_label.text = shop.display_name
	back_button.visible = true
	shop_list_view.visible = false
	shop_detail_view.visible = true
	shop_name_label.text = shop.display_name
	description_label.text = shop.description
	_apply_shop_portrait(shop)
	_play_shop_bgm(shop)
	_setup_item_tabs(shop)
	_refresh_item_grid(shop)


func _apply_shop_portrait(shop: ShopData) -> void:
	portrait_rect.texture = shop.portrait
	portrait_rect.visible = shop.portrait != null


func _setup_item_tabs(shop: ShopData) -> void:
	_is_setting_item_tabs = true
	item_tab_bar.clear_tabs()
	var tabs := shop.get_tabs()
	if tabs.is_empty():
		item_tab_bar.visible = false
		_current_shop_tab_index = 0
		_is_setting_item_tabs = false
		return

	item_tab_bar.visible = true
	for tab in tabs:
		item_tab_bar.add_tab(tab.display_name)

	_current_shop_tab_index = clampi(_current_shop_tab_index, 0, tabs.size() - 1)
	item_tab_bar.current_tab = _current_shop_tab_index
	_is_setting_item_tabs = false


func _get_current_shop_tab_id(shop: ShopData) -> StringName:
	var tabs := shop.get_tabs()
	if tabs.is_empty():
		return &""
	_current_shop_tab_index = clampi(_current_shop_tab_index, 0, tabs.size() - 1)
	return tabs[_current_shop_tab_index].tab_id


func _play_shop_bgm(shop: ShopData) -> void:
	if shop == null or shop.shop_bgm == null:
		_restore_previous_bgm_if_needed()
		return
	if _active_shop_bgm == shop.shop_bgm:
		return

	var audio_player := get_node_or_null("/root/AudioPlayer")
	if audio_player == null or not audio_player.has_method("play_bgm"):
		return

	if not _has_previous_bgm:
		if audio_player.has_method("get_current_bgm"):
			_previous_bgm = audio_player.call("get_current_bgm") as AudioStream
		else:
			_previous_bgm = null
		if audio_player.has_method("get_bgm_playback_position"):
			_previous_bgm_position = float(audio_player.call("get_bgm_playback_position"))
		else:
			_previous_bgm_position = 0.0
		_has_previous_bgm = true

	_ensure_stream_loop(shop.shop_bgm)
	audio_player.call("play_bgm", shop.shop_bgm, 0.0, false)
	_active_shop_bgm = shop.shop_bgm


func _ensure_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", true)
			return


func _restore_previous_bgm_if_needed() -> void:
	if not _has_previous_bgm:
		_active_shop_bgm = null
		return

	var audio_player := get_node_or_null("/root/AudioPlayer")
	if audio_player != null:
		if _previous_bgm != null and audio_player.has_method("play_bgm"):
			audio_player.call("play_bgm", _previous_bgm, _previous_bgm_position, true)
		elif audio_player.has_method("stop_bgm"):
			audio_player.call("stop_bgm")

	_previous_bgm = null
	_previous_bgm_position = 0.0
	_has_previous_bgm = false
	_active_shop_bgm = null


func _refresh_item_grid(shop: ShopData) -> void:
	_hide_item_popup()
	_clear_item_grid()
	var tab_id := _get_current_shop_tab_id(shop)
	var entries := shop.get_available_items_for_tab(tab_id)
	if entries.is_empty():
		detail_label.text = "このタブの商品はまだありません。"
		return

	var credits := _get_wallet_credits()
	for entry in entries:
		item_grid.add_child(_create_item_card(entry, credits))

	detail_label.text = "所持クレジット: %d" % credits


func _create_item_card(entry: ShopItemData, credits: int) -> Control:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(124, 176)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.tooltip_text = entry.get_description()
	card_panel.add_theme_stylebox_override("panel", _create_item_card_style())
	card_panel.mouse_entered.connect(Callable(self, "_show_item_popup").bind(entry, card_panel))
	card_panel.mouse_exited.connect(_hide_item_popup)

	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 8.0
	card.offset_top = 8.0
	card.offset_right = -8.0
	card.offset_bottom = -8.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 5)
	card_panel.add_child(card)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(72, 72)
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

	var price_label := Label.new()
	price_label.text = "%d C" % entry.get_unit_price()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.add_theme_font_size_override("font_size", 14)
	card.add_child(price_label)

	var base_amount: int = maxi(entry.amount, 1)
	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(0, 30)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.text = "%d個購入" % base_amount
	buy_button.tooltip_text = "購入数: 通常 %d個 / Shift %d個 / Ctrl %d個" % [base_amount, base_amount * 10, base_amount * 100]
	buy_button.disabled = not entry.is_available or entry.get_unit_price() * base_amount > credits
	buy_button.add_theme_stylebox_override("normal", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("hover", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("pressed", _create_purchase_button_style())
	buy_button.add_theme_stylebox_override("focus", _create_purchase_button_style())
	buy_button.pressed.connect(Callable(self, "_on_buy_pressed").bind(entry))
	buy_button.mouse_entered.connect(Callable(self, "_show_item_popup").bind(entry, card_panel))
	buy_button.mouse_exited.connect(_hide_item_popup)
	card.add_child(buy_button)

	return card_panel


func _create_item_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 1.0)
	style.border_color = Color(0.08, 0.18, 0.22, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _create_purchase_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.012, 0.02, 1.0)
	style.border_color = Color(0.12, 0.28, 0.34, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _setup_item_popup() -> void:
	if _item_popup != null:
		return

	_item_popup = PopupPanel.new()
	_item_popup.name = "ItemPopup"
	_item_popup.hide()
	add_child(_item_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_item_popup.add_child(margin)

	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(280, 124)
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	_item_popup_name_label = Label.new()
	_item_popup_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_popup_name_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(_item_popup_name_label)

	_item_popup_description_label = Label.new()
	_item_popup_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_popup_description_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_item_popup_description_label)

	_item_popup_price_label = Label.new()
	_item_popup_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_item_popup_price_label.add_theme_font_size_override("font_size", 14)
	rows.add_child(_item_popup_price_label)


func _show_item_popup(entry: ShopItemData, anchor: Control) -> void:
	if entry == null or anchor == null:
		return
	_setup_item_popup()

	var base_amount: int = maxi(entry.amount, 1)
	_item_popup_name_label.text = entry.get_display_name()
	_item_popup_description_label.text = entry.get_description()
	_item_popup_price_label.text = "単価: %d C\n購入: %d個 / Shift %d個 / Ctrl %d個" % [entry.get_unit_price(), base_amount, base_amount * 10, base_amount * 100]

	var global_rect := anchor.get_global_rect()
	var viewport_size := get_viewport_rect().size
	var popup_size := Vector2i(304, 160)
	var popup_pos := Vector2i(
		int(global_rect.position.x + global_rect.size.x + 12.0),
		int(global_rect.position.y)
	)

	if popup_pos.x + popup_size.x > int(viewport_size.x):
		popup_pos.x = int(global_rect.position.x) - popup_size.x - 12
	if popup_pos.y + popup_size.y > int(viewport_size.y):
		popup_pos.y = int(viewport_size.y) - popup_size.y - 8

	popup_pos.x = maxi(popup_pos.x, 8)
	popup_pos.y = maxi(popup_pos.y, 8)
	_item_popup.popup(Rect2i(popup_pos, popup_size))


func _hide_item_popup() -> void:
	if _item_popup != null and _item_popup.visible:
		_item_popup.hide()


func _load_entry_icon(entry: ShopItemData) -> Texture2D:
	if entry == null:
		return null
	var icon_path := entry.get_icon_path()
	if icon_path == "":
		return null
	var resource := load(icon_path)
	return resource as Texture2D


func _on_shop_selected(shop_index: int) -> void:
	_current_shop_tab_index = 0
	_show_shop_detail(shop_index)


func _on_back_pressed() -> void:
	_show_shop_list()


func _on_item_tab_changed(tab_index: int) -> void:
	if _is_setting_item_tabs:
		return
	_current_shop_tab_index = tab_index
	_refresh_current_shop_detail()


func _on_buy_pressed(entry: ShopItemData) -> void:
	if entry == null:
		return
	_resolve_inventory_module()
	if _inventory_module == null:
		detail_label.text = "購入先のインベントリが見つかりません。"
		return

	var purchase_amount: int = _get_purchase_amount(entry)
	var total_price: int = entry.get_unit_price() * purchase_amount
	if not _spend_credits(total_price, entry):
		_refresh_current_shop_detail()
		detail_label.text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, _get_wallet_credits()]
		return

	if not _add_entry_to_inventory(entry, purchase_amount):
		_refund_credits(total_price, entry)
		_refresh_current_shop_detail()
		detail_label.text = "インベントリに空きがありません。購入を取り消しました。"
		return

	_refresh_current_shop_detail()
	detail_label.text = "購入しました: %s x%d" % [entry.get_display_name(), purchase_amount]


func _get_purchase_amount(entry: ShopItemData) -> int:
	return maxi(entry.amount, 1) * _get_purchase_multiplier()


func _get_purchase_multiplier() -> int:
	if Input.is_key_pressed(KEY_CTRL):
		return 100
	if Input.is_key_pressed(KEY_SHIFT):
		return 10
	return 1


func _refresh_current_shop_detail() -> void:
	if _selected_shop_index < 0 or _selected_shop_index >= _shops.size():
		_show_shop_list()
		return
	_show_shop_detail(_selected_shop_index)


func _spend_credits(amount: int, entry: ShopItemData) -> bool:
	if amount <= 0:
		return true
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_method("spend"):
		push_warning("CreditWallet が見つかりません。ショップ購入を無料扱いにします。")
		return true
	return wallet.call("spend", amount, "shop_buy:%s" % entry.get_item_id()) == true


func _refund_credits(amount: int, entry: ShopItemData) -> void:
	if amount <= 0:
		return
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_method("add"):
		return
	wallet.call("add", amount, "shop_refund:%s" % entry.get_item_id())


func _add_entry_to_inventory(entry: ShopItemData, purchase_amount: int) -> bool:
	if _inventory_module == null:
		return false
	if not _inventory_module.has_method("add_item"):
		return false
	return _inventory_module.call(
		"add_item",
		entry.get_category_id(),
		entry.get_item_id(),
		entry.get_display_name(),
		maxi(purchase_amount, 1),
		entry.get_icon_path()
	) == true


func _get_wallet_credits() -> int:
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_method("get_credits"):
		return 0
	return int(wallet.call("get_credits"))


func _clear_shop_list() -> void:
	for child in shop_list.get_children():
		child.queue_free()


func _clear_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()


func _on_wallet_balance_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	if not visible:
		return
	if _selected_shop_index >= 0:
		_refresh_current_shop_detail()
