extends Node
class_name BasicIncomeSystem

signal basic_income_received(amount: int, period_index: int, season_id: String, season_day: int)

const SAVE_KEY_LAST_PAID_PERIOD := "basic_income_last_paid_period"
const DEFAULT_INCOME_AMOUNT := 1000

@export var income_amount: int = DEFAULT_INCOME_AMOUNT
@export var income_reason: String = "basic_income"

## trueにすると、ゲーム開始直後の1年目春1日にも支給する。
## falseなら、最初の支給は2つ目の季節の1日目から。
@export var grant_on_first_period_start: bool = false

var _clock: GameClockSystem
var _wallet: Node
var _last_paid_period_index: int = 0


func _ready() -> void:
	add_to_group("basic_income_system")
	call_deferred("_connect_systems")


func _connect_systems() -> void:
	_clock = _find_clock()
	_wallet = _find_wallet()

	if _clock == null:
		push_warning("BasicIncomeSystem: GameClockSystem が見つかりません。")
		return

	if _wallet == null:
		push_warning("BasicIncomeSystem: CreditWallet が見つかりません。")
		return

	if not _wallet.has_method("add"):
		push_warning("BasicIncomeSystem: CreditWallet に add(amount, reason) がありません。")
		return

	if not _clock.day_changed.is_connected(_on_day_changed):
		_clock.day_changed.connect(_on_day_changed)

	if grant_on_first_period_start and _clock.get_season_period_index() == 1:
		_try_grant_income_for_current_day()


func to_save_data() -> Dictionary:
	return {
		SAVE_KEY_LAST_PAID_PERIOD: _last_paid_period_index,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.has(SAVE_KEY_LAST_PAID_PERIOD):
		_last_paid_period_index = max(0, int(data[SAVE_KEY_LAST_PAID_PERIOD]))


func _find_clock() -> GameClockSystem:
	var autoload_clock := get_node_or_null("/root/GameClock")
	if autoload_clock is GameClockSystem:
		return autoload_clock

	var group_nodes := get_tree().get_nodes_in_group("game_clock")
	if group_nodes.size() > 0 and group_nodes[0] is GameClockSystem:
		return group_nodes[0]

	return null


func _find_wallet() -> Node:
	var autoload_wallet := get_node_or_null("/root/CreditWallet")
	if autoload_wallet != null:
		return autoload_wallet

	var group_nodes := get_tree().get_nodes_in_group("credit_wallet")
	if group_nodes.size() > 0:
		return group_nodes[0]

	return null


func _on_day_changed(_day: int) -> void:
	_try_grant_income_for_current_day()


func _try_grant_income_for_current_day() -> bool:
	if _clock == null or _wallet == null:
		return false

	if income_amount <= 0:
		return false

	if not _clock.is_first_day_of_season():
		return false

	var period_index := _clock.get_season_period_index()
	if period_index <= 1 and not grant_on_first_period_start:
		return false

	if period_index == _last_paid_period_index:
		return false

	var added := bool(_wallet.call("add", income_amount, income_reason))
	if not added:
		return false

	_last_paid_period_index = period_index
	basic_income_received.emit(
		income_amount,
		period_index,
		_clock.get_season_id(),
		_clock.get_season_day()
	)

	return true
