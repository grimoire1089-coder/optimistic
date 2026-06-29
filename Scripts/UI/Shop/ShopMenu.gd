extends PanelContainer
class_name ShopMenu

@export var shop_database: ShopDatabase
@export var actor_path: NodePath = NodePath("../../Robin")
@export var inventory_module_child_name: StringName = &"RobinInventoryModule"

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var tab_bar: TabBar = $MarginContainer/Rows/TabBar
@onready var description_label: Label = $MarginContainer/Rows/DescriptionLabel
@onready var item_list: VBoxContainer = $MarginContainer/Rows/ScrollContainer/ItemList
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _inventory_module: RobinInventoryModule
var _shops: Array[ShopData] = []
var _current_shop_index: int = 0


func _ready() -> void:
	visible = false
	add_to_group(&"shop_menu")
	close_button.pressed.connect(close_menu)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_connect_wallet_signal()
	_resolve_inventory_module()
	_setup_tabs()
	_refresh()


func open_menu() -> void:
	visible = true
	_resolve_inventory_module()
	_setup_tabs()
	_refresh()


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	visible = not visible
	if visible:
		_resolve_inventory_module()
		_setup_tabs()
		_refresh()


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


func _setup_tabs() -> void:
	tab_bar.clear_tabs()
	_shops.clear()

	if shop_database != null:
		_shops = shop_database.get_shops()

	for shop in _shops:
		tab_bar.add_tab(shop.display_name)

	_current_shop_index = clampi(_current_shop_index, 0, max(_shops.size() - 1, 0))
	if _shops.size() > 0:
		tab_bar.current_tab = _current_shop_index


func _refresh() -> void:
	_clear_item_list()
	title_label.text = "ショップ"

	if shop_database == null:
		description_label.text = "ショップデータベースが未設定です。"
		detail_label.text = "ShopDatabase を割り当ててください。"
		return

	if _shops.is_empty():
		_setup_tabs()

	if _shops.is_empty():
		description_label.text = "登録されたショップがありません。"
		detail_label.text = "Data/Shops に ShopData を追加してください。"
		return

	var shop := _shops[_current_shop_index]
	description_label.text = shop.description

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


func _on_buy_pressed(entry: ShopItemData) -> void:
	if entry == null:
		return
	_resolve_inventory_module()
	if _inventory_module == null:
		detail_label.text = "購入先のインベントリが見つかりません。"
		return

	var total_price := entry.get_total_price()
	if not _spend_credits(total_price, entry):
		detail_label.text = "クレジットが足りません。必要: %d / 所持: %d" % [total_price, _get_wallet_credits()]
		_refresh()
		return

	if not _add_entry_to_inventory(entry):
		_refund_credits(total_price, entry)
		detail_label.text = "インベントリに空きがありません。購入を取り消しました。"
		_refresh()
		return

	detail_label.text = "購入しました: %s x%d" % [entry.get_display_name(), max(entry.amount, 1)]
	_refresh()


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


func _clear_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()


func _on_tab_changed(tab_index: int) -> void:
	_current_shop_index = tab_index
	_refresh()


func _on_wallet_balance_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	if visible:
		_refresh()
