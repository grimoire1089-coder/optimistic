extends Node

signal balance_changed(new_balance: int, delta: int, reason: String)
signal transaction_failed(required: int, current: int, reason: String)

const SAVE_KEY := "credits"
const DEFAULT_CREDITS := 0

var _credits: int = DEFAULT_CREDITS

var credits: int:
	get:
		return _credits


func _ready() -> void:
	# Autoloadされた時点では初期値だけを持つ。
	# セーブデータがある場合は、SaveManager側から apply_save_data() を呼ぶ。
	balance_changed.emit(_credits, 0, "ready")


func get_credits() -> int:
	return _credits


func set_credits(value: int, reason: String = "set") -> void:
	var new_value: int = max(value, 0)
	var delta: int = new_value - _credits

	if delta == 0:
		return

	_credits = new_value
	balance_changed.emit(_credits, delta, reason)


func add(amount: int, reason: String = "add") -> bool:
	if amount <= 0:
		return false

	set_credits(_credits + amount, reason)
	return true


func can_spend(amount: int) -> bool:
	if amount < 0:
		return false

	return _credits >= amount


func spend(amount: int, reason: String = "spend") -> bool:
	if amount < 0:
		transaction_failed.emit(amount, _credits, reason)
		return false

	if amount == 0:
		return true

	if not can_spend(amount):
		transaction_failed.emit(amount, _credits, reason)
		return false

	set_credits(_credits - amount, reason)
	return true


func reset(reason: String = "reset") -> void:
	set_credits(DEFAULT_CREDITS, reason)


func to_save_data() -> Dictionary:
	return {
		SAVE_KEY: _credits,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.has(SAVE_KEY):
		set_credits(int(data[SAVE_KEY]), "load")
