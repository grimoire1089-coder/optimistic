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
@onready var shop_list: VBoxContainer = $MarginContainer/Rows/ShopListView/ShopListScroll/ShopList
@onready var shop_detail_view: VBoxContainer = $MarginContainer/Rows/ShopDetailView
@onready var portrait_rect: TextureRect = $MarginContainer/Rows/ShopDetailView/ShopTopArea/PortraitFrame/Portrait
@onready var shop_name_label: Label = $MarginContainer/Rows/ShopDetailView/ShopTopArea/ShopInfo/ShopNameLabel
@onready var description_label: Label = $MarginContainer/Rows/ShopDetailView/ShopTopArea/ShopInfo/DescriptionLabel
@onready var item_list: VBoxContainer = $MarginContainer/Rows/ShopDetailView/ItemScroll/ItemList
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _inventory_module: RobinInventoryModule
var _shops: Array[ShopData] = []
var _selected_shop_index: int = -1
var _previous_bgm: AudioStream
var _previous_bgm_position: float = 0.0
var _has_previous_bgm: bool = false
var _active_shop_bgm: AudioStream


func _ready() -> void:
	visible = false
	add_to_group(&"shop_menu")
	back_button.text = "戻る"
	close_button.text = "X"
	guide_label.text = "行きたいお店を選んでください。"
	back_button.pressed.connect(_on_back_pressed)
	close_button.pressed.connect(close_menu)
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
	_restore_previous_bgm_if_needed()
	_selected_shop_index = -1
	title_label.text = "ショップ一覧"
	back_button.visible = false
	shop_list_view.visible = true
	shop_detail_view.visible = false
	_clear_shop_list()
	_clear_item_list()

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
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = "%s\n%s" % [shop.display_name, shop.description]
	button.pressed.connect(Callable(self, "_on_shop_selected").bind(index))
	return button


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
	_refresh_item_list(shop)


func _apply_shop_portrait(shop: ShopData) -> void:
	portrait_rect.texture = shop.portrait
	portrait_rect.visible = shop.portrait != null


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

	audio_player.call("play_bgm", shop.shop_bgm, 0.0, false)
	_active_shop_bgm = shop.shop_bgm


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


func _refresh_item_list(shop: ShopData) -> void:
	_clear_item_list()
	var entries := shop.get_available_items()
	if entries.is_empty():
		detail_label.text = "このショップの商品はまだありません。"
		return

	var credits := _get_wallet_credits()
	for entry in entries:
		item_list.add_child(_create_item_button(entry, credits))

	detail_label.text = "所持クレジット: %d" % credits


func _create_item_button(entry: ShopItemData, credits: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true

	var total_price := entry.get_total_price()
	button.text = "%s x%d\n%d C" % [entry.get_display_name(), max(entry.amount, 1), total_price]
	button.tooltip_text = entry.get_description()
	button.disabled = not entry.is_available or total_price > credits
	if total_price > credits:
		button.tooltip_text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, credits]
	button.pressed.connect(Callable(self, "_on_buy_pressed").bind(entry))
	return button


func _on_shop_selected(shop_index: int) -> void:
	_show_shop_detail(shop_index)


func _on_back_pressed() -> void:
	_show_shop_list()


func _on_buy_pressed(entry: ShopItemData) -> void:
	if entry == null:
		return
	_resolve_inventory_module()
	if _inventory_module == null:
		detail_label.text = "購入先のインベントリが見つかりません。"
		return

	var total_price := entry.get_total_price()
	if not _spend_credits(total_price, entry):
		_refresh_current_shop_detail()
		detail_label.text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, _get_wallet_credits()]
		return

	if not _add_entry_to_inventory(entry):
		_refund_credits(total_price, entry)
		_refresh_current_shop_detail()
		detail_label.text = "インベントリに空きがありません。購入を取り消しました。"
		return

	_refresh_current_shop_detail()
	detail_label.text = "購入しました: %s x%d" % [entry.get_display_name(), max(entry.amount, 1)]


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


func _add_entry_to_inventory(entry: ShopItemData) -> bool:
	if _inventory_module == null:
		return false
	if not _inventory_module.has_method("add_item"):
		return false
	return _inventory_module.call(
		"add_item",
		entry.get_category_id(),
		entry.get_item_id(),
		entry.get_display_name(),
		max(entry.amount, 1),
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


func _clear_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()


func _on_wallet_balance_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	if not visible:
		return
	if _selected_shop_index >= 0:
		_refresh_current_shop_detail()
