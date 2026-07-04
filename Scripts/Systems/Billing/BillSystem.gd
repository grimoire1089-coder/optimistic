extends Node
class_name BillingSystem

signal bills_changed
signal bill_arrived(bill: Dictionary)
signal bill_paid(bill_id: String, amount: int)
signal usage_changed(water_units: int, electricity_units: int)

const BILL_TYPE_RENT := "rent"
const BILL_TYPE_WATER := "water"
const BILL_TYPE_ELECTRICITY := "electricity"
const SAVE_KEY_BILLS := "bills"
const SAVE_KEY_WATER_USAGE := "water_usage_units"
const SAVE_KEY_ELECTRICITY_USAGE := "electricity_usage_units"
const SAVE_KEY_LAST_BILLED_PERIOD := "last_billed_period_index"

@export var rent_amount: int = 300
@export var water_unit_price: int = 5
@export var electricity_unit_price: int = 8
@export var generate_on_first_period_start: bool = true

var _clock: GameClockSystem
var _wallet: Node
var _bills: Array[Dictionary] = []
var _water_usage_units: int = 0
var _electricity_usage_units: int = 0
var _last_billed_period_index: int = 0
var _pending_log_messages: Array[String] = []


func _ready() -> void:
	add_to_group(&"bill_system")
	_connect_tree_signals()
	call_deferred("_deferred_ready")


func reset_for_new_game() -> void:
	_bills.clear()
	_water_usage_units = 0
	_electricity_usage_units = 0
	_last_billed_period_index = 0
	_pending_log_messages.clear()
	_connect_systems()
	if generate_on_first_period_start:
		_try_generate_bills_for_current_day()
	bills_changed.emit()
	usage_changed.emit(_water_usage_units, _electricity_usage_units)


func record_water_usage(units: int, _reason: String = "") -> void:
	if units <= 0:
		return
	_water_usage_units += units
	usage_changed.emit(_water_usage_units, _electricity_usage_units)
	bills_changed.emit()


func record_electricity_usage(units: int, _reason: String = "") -> void:
	if units <= 0:
		return
	_electricity_usage_units += units
	usage_changed.emit(_water_usage_units, _electricity_usage_units)
	bills_changed.emit()


func get_bills(include_paid: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bill in _bills:
		if include_paid or not bool(bill.get("paid", false)):
			result.append(bill.duplicate(true))
	return result


func get_unpaid_bills() -> Array[Dictionary]:
	return get_bills(false)


func get_unpaid_total() -> int:
	var total := 0
	for bill in _bills:
		if bool(bill.get("paid", false)):
			continue
		total += maxi(int(bill.get("amount", 0)), 0)
	return total


func get_current_usage_summary() -> Dictionary:
	return {
		"water_units": _water_usage_units,
		"electricity_units": _electricity_usage_units,
		"water_estimate": _water_usage_units * maxi(water_unit_price, 0),
		"electricity_estimate": _electricity_usage_units * maxi(electricity_unit_price, 0),
	}


func pay_bill(bill_id: String) -> bool:
	if bill_id.is_empty():
		return false
	for index in range(_bills.size()):
		var bill := _bills[index].duplicate(true)
		if String(bill.get("id", "")) != bill_id:
			continue
		if bool(bill.get("paid", false)):
			return true
		var amount := maxi(int(bill.get("amount", 0)), 0)
		if amount > 0:
			var wallet := _get_wallet()
			if wallet == null or not wallet.has_method("spend"):
				return false
			if not bool(wallet.call("spend", amount, "bill_%s" % String(bill.get("type", "")))):
				return false
		bill["paid"] = true
		bill["paid_day"] = _get_current_day()
		_bills[index] = bill
		bill_paid.emit(bill_id, amount)
		bills_changed.emit()
		return true
	return false


func pay_all_unpaid_bills() -> bool:
	var total := get_unpaid_total()
	if total <= 0:
		_mark_zero_amount_bills_paid()
		return true
	var wallet := _get_wallet()
	if wallet == null or not wallet.has_method("spend"):
		return false
	if not bool(wallet.call("spend", total, "bill_pay_all")):
		return false

	var paid_day := _get_current_day()
	for index in range(_bills.size()):
		var bill := _bills[index].duplicate(true)
		if bool(bill.get("paid", false)):
			continue
		bill["paid"] = true
		bill["paid_day"] = paid_day
		_bills[index] = bill

	bill_paid.emit("all", total)
	bills_changed.emit()
	return true


func to_save_data() -> Dictionary:
	return {
		SAVE_KEY_BILLS: _bills.duplicate(true),
		SAVE_KEY_WATER_USAGE: _water_usage_units,
		SAVE_KEY_ELECTRICITY_USAGE: _electricity_usage_units,
		SAVE_KEY_LAST_BILLED_PERIOD: _last_billed_period_index,
	}


func apply_save_data(data: Dictionary) -> void:
	_bills.clear()
	var raw_bills: Array = data.get(SAVE_KEY_BILLS, [])
	for entry in raw_bills:
		if entry is Dictionary:
			_bills.append((entry as Dictionary).duplicate(true))
	_water_usage_units = maxi(int(data.get(SAVE_KEY_WATER_USAGE, 0)), 0)
	_electricity_usage_units = maxi(int(data.get(SAVE_KEY_ELECTRICITY_USAGE, 0)), 0)
	_last_billed_period_index = maxi(int(data.get(SAVE_KEY_LAST_BILLED_PERIOD, 0)), 0)
	bills_changed.emit()
	usage_changed.emit(_water_usage_units, _electricity_usage_units)


func _deferred_ready() -> void:
	_connect_systems()
	if generate_on_first_period_start:
		_try_generate_bills_for_current_day()
	flush_pending_log_messages()


func _connect_systems() -> void:
	_clock = _find_clock()
	_wallet = _find_wallet()
	if _clock != null and not _clock.day_changed.is_connected(_on_day_changed):
		_clock.day_changed.connect(_on_day_changed)


func _connect_tree_signals() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var callable := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callable):
		tree.node_added.connect(callable)


func _on_day_changed(_day: int) -> void:
	_try_generate_bills_for_current_day()


func _on_tree_node_added(_node: Node) -> void:
	if not _pending_log_messages.is_empty():
		call_deferred("flush_pending_log_messages")


func _try_generate_bills_for_current_day() -> bool:
	if _clock == null:
		_connect_systems()
	if _clock == null:
		return false
	if not _clock.is_first_day_of_season():
		return false

	var period_index := _clock.get_season_period_index()
	if period_index <= 1 and not generate_on_first_period_start:
		return false
	if period_index == _last_billed_period_index:
		return false

	var issued_any := false
	issued_any = _issue_bill(BILL_TYPE_RENT, rent_amount, 0) or issued_any
	issued_any = _issue_bill(BILL_TYPE_WATER, _water_usage_units * maxi(water_unit_price, 0), _water_usage_units) or issued_any
	issued_any = _issue_bill(BILL_TYPE_ELECTRICITY, _electricity_usage_units * maxi(electricity_unit_price, 0), _electricity_usage_units) or issued_any

	_water_usage_units = 0
	_electricity_usage_units = 0
	_last_billed_period_index = period_index
	usage_changed.emit(_water_usage_units, _electricity_usage_units)

	if issued_any:
		bills_changed.emit()
		_push_message("請求書が届きました。")
	return issued_any


func _issue_bill(bill_type: String, amount: int, usage_units: int) -> bool:
	var safe_amount := maxi(amount, 0)
	var bill := {
		"id": "%s_%d_%d" % [bill_type, _clock.get_season_period_index(), _bills.size() + 1],
		"type": bill_type,
		"title": _get_bill_type_label(bill_type),
		"amount": safe_amount,
		"usage_units": maxi(usage_units, 0),
		"season_period_index": _clock.get_season_period_index(),
		"season_year": _clock.get_season_year(),
		"season_id": _clock.get_season_id(),
		"season_day": _clock.get_season_day(),
		"issued_day": _clock.day,
		"paid": safe_amount <= 0,
		"paid_day": _clock.day if safe_amount <= 0 else 0,
	}
	_bills.append(bill)
	bill_arrived.emit(bill.duplicate(true))
	return true


func _mark_zero_amount_bills_paid() -> void:
	var changed := false
	var paid_day := _get_current_day()
	for index in range(_bills.size()):
		var bill := _bills[index].duplicate(true)
		if bool(bill.get("paid", false)):
			continue
		if int(bill.get("amount", 0)) > 0:
			continue
		bill["paid"] = true
		bill["paid_day"] = paid_day
		_bills[index] = bill
		changed = true
	if changed:
		bills_changed.emit()


func _get_bill_type_label(bill_type: String) -> String:
	match bill_type:
		BILL_TYPE_RENT:
			return "家賃"
		BILL_TYPE_WATER:
			return "水道"
		BILL_TYPE_ELECTRICITY:
			return "電気"
		_:
			return bill_type


func _find_clock() -> GameClockSystem:
	var autoload_clock := get_node_or_null("/root/GameClock")
	if autoload_clock is GameClockSystem:
		return autoload_clock
	var group_clock := get_tree().get_first_node_in_group("game_clock")
	if group_clock is GameClockSystem:
		return group_clock
	return null


func _find_wallet() -> Node:
	var autoload_wallet := get_node_or_null("/root/CreditWallet")
	if autoload_wallet != null:
		return autoload_wallet
	return get_tree().get_first_node_in_group("credit_wallet")


func _get_wallet() -> Node:
	if _wallet != null and is_instance_valid(_wallet):
		return _wallet
	_wallet = _find_wallet()
	return _wallet


func _get_current_day() -> int:
	if _clock != null:
		return _clock.day
	return 0


func flush_pending_log_messages() -> void:
	if _pending_log_messages.is_empty():
		return
	var message_log := _find_message_log()
	if message_log == null:
		return
	for message in _pending_log_messages:
		message_log.call("add_message", message)
	_pending_log_messages.clear()


func _find_message_log() -> Node:
	var group_nodes := get_tree().get_nodes_in_group("message_log")
	for node in group_nodes:
		if node != null and node.has_method("add_message"):
			return node
	return null


func _push_message(message: String) -> void:
	var message_log := _find_message_log()
	if message_log == null:
		_pending_log_messages.append(message)
		return
	message_log.call("add_message", message)
