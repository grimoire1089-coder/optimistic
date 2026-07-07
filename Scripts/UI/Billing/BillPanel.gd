extends PanelContainer
class_name BillPanel

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const PANEL_SIZE := Vector2(480.0, 456.0)
const BILL_CARD_HEIGHT := 82.0

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var summary_label: Label = $MarginContainer/Rows/SummaryLabel
@onready var usage_label: Label = $MarginContainer/Rows/UsageLabel
@onready var bill_list: VBoxContainer = $MarginContainer/Rows/BillScroll/BillList
@onready var empty_label: Label = $MarginContainer/Rows/BillScroll/BillList/EmptyLabel
@onready var pay_all_button: Button = $MarginContainer/Rows/PayAllButton

var _bill_system: Node


func _ready() -> void:
	visible = false
	add_to_group(&"bill_ui")
	close_button.pressed.connect(close)
	pay_all_button.pressed.connect(_on_pay_all_pressed)
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	_connect_bill_system()
	_connect_wallet_signal()
	_refresh()


func open() -> void:
	_apply_bottom_right_layout()
	visible = true
	_refresh()


func close() -> void:
	visible = false


func close_menu() -> void:
	close()


func toggle() -> void:
	if visible:
		close()
		return
	open()


func toggle_bill_panel() -> void:
	toggle()


func _apply_bottom_right_layout() -> void:
	custom_minimum_size = PANEL_SIZE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -BOTTOM_RIGHT_MARGIN.x - PANEL_SIZE.x
	offset_top = -BOTTOM_RIGHT_MARGIN.y - PANEL_SIZE.y
	offset_right = -BOTTOM_RIGHT_MARGIN.x
	offset_bottom = -BOTTOM_RIGHT_MARGIN.y


func _connect_bill_system() -> void:
	var bill_system := _get_bill_system()
	if bill_system == null:
		return
	for signal_name in [&"bills_changed", &"usage_changed"]:
		if not bill_system.has_signal(signal_name):
			continue
		var callable := Callable(self, "_refresh")
		if not bill_system.is_connected(signal_name, callable):
			bill_system.connect(signal_name, callable)


func _connect_wallet_signal() -> void:
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_signal("balance_changed"):
		return
	var callable := Callable(self, "_refresh")
	if not wallet.is_connected("balance_changed", callable):
		wallet.connect("balance_changed", callable)


func _get_bill_system() -> Node:
	if _bill_system != null and is_instance_valid(_bill_system):
		return _bill_system
	_bill_system = get_node_or_null("/root/BillSystem")
	if _bill_system != null:
		return _bill_system
	_bill_system = get_tree().get_first_node_in_group(&"bill_system")
	return _bill_system


func _refresh(_a = null, _b = null, _c = null) -> void:
	var bill_system := _get_bill_system()
	title_label.text = "請求"
	if bill_system == null:
		summary_label.text = "請求システムが見つかりません。"
		usage_label.text = ""
		_clear_bill_cards()
		empty_label.visible = true
		empty_label.text = "表示できる請求書はありません。"
		pay_all_button.disabled = true
		return

	var unpaid_total := int(bill_system.call("get_unpaid_total"))
	var bills: Array = bill_system.call("get_bills", true)
	var usage: Dictionary = bill_system.call("get_current_usage_summary")
	summary_label.text = "未払い: CR %d / 請求書 %d件" % [unpaid_total, bills.size()]
	usage_label.text = "今季使用量  水道 %d / 電気 %d" % [
		int(usage.get("water_units", 0)),
		int(usage.get("electricity_units", 0)),
	]
	pay_all_button.text = "未払いをまとめて支払う"
	pay_all_button.disabled = unpaid_total <= 0 or not _can_spend(unpaid_total)

	_clear_bill_cards()
	if bills.is_empty():
		empty_label.visible = true
		empty_label.text = "届いている請求書はありません。"
		return

	empty_label.visible = false
	for index in range(bills.size() - 1, -1, -1):
		var bill: Dictionary = bills[index]
		bill_list.add_child(_create_bill_card(bill))


func _create_bill_card(bill: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, BILL_CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", _make_card_style(bool(bill.get("paid", false))))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	rows.add_child(top_row)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "%s / CR %d" % [String(bill.get("title", "")), int(bill.get("amount", 0))]
	title.add_theme_font_size_override("font_size", 15)
	top_row.add_child(title)

	var pay_button := Button.new()
	pay_button.custom_minimum_size = Vector2(80.0, 26.0)
	pay_button.text = "支払済み" if bool(bill.get("paid", false)) else "支払う"
	pay_button.disabled = bool(bill.get("paid", false)) or int(bill.get("amount", 0)) <= 0 or not _can_spend(int(bill.get("amount", 0)))
	pay_button.pressed.connect(Callable(self, "_on_pay_bill_pressed").bind(String(bill.get("id", ""))))
	top_row.add_child(pay_button)

	var meta := Label.new()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.68, 0.88, 0.94, 1.0))
	meta.text = _make_bill_meta_text(bill)
	rows.add_child(meta)

	return card


func _make_bill_meta_text(bill: Dictionary) -> String:
	var issued_text := "%d年目 %s / %d日目発行" % [
		int(bill.get("season_year", 1)),
		_get_season_label(String(bill.get("season_id", ""))),
		int(bill.get("season_day", 1)),
	]
	var usage_units := int(bill.get("usage_units", 0))
	var usage_text := ""
	match String(bill.get("type", "")):
		"water":
			usage_text = "水道使用量 %d" % usage_units
		"electricity":
			usage_text = "電気使用量 %d" % usage_units
		_:
			usage_text = "固定費"
	var status_text := "支払済み" if bool(bill.get("paid", false)) else "未払い"
	return "%s / %s / %s" % [issued_text, usage_text, status_text]


func _get_season_label(season_id: String) -> String:
	match season_id:
		"spring":
			return "春"
		"summer":
			return "夏"
		"autumn":
			return "秋"
		"winter":
			return "冬"
		_:
			return season_id


func _on_pay_bill_pressed(bill_id: String) -> void:
	var bill_system := _get_bill_system()
	if bill_system == null or not bill_system.has_method("pay_bill"):
		return
	bill_system.call("pay_bill", bill_id)
	_refresh()


func _on_pay_all_pressed() -> void:
	var bill_system := _get_bill_system()
	if bill_system == null or not bill_system.has_method("pay_all_unpaid_bills"):
		return
	bill_system.call("pay_all_unpaid_bills")
	_refresh()


func _can_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_method("can_spend"):
		return false
	return bool(wallet.call("can_spend", amount))


func _clear_bill_cards() -> void:
	for child in bill_list.get_children():
		if child == empty_label:
			continue
		child.queue_free()


func _make_card_style(is_paid: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.050, 0.060, 0.92) if is_paid else Color(0.065, 0.050, 0.040, 0.94)
	style.border_color = Color(0.16, 0.48, 0.56, 0.70) if is_paid else Color(1.0, 0.62, 0.18, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(2.0)
	return style
