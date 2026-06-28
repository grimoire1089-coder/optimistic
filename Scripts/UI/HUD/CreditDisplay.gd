extends Label

@export var prefix: String = "CR "
@export var use_separator: bool = true
@export var zero_pad_digits: int = 0


func _ready() -> void:
	CreditWallet.balance_changed.connect(_on_balance_changed)
	_refresh(CreditWallet.get_credits())


func _exit_tree() -> void:
	if CreditWallet.balance_changed.is_connected(_on_balance_changed):
		CreditWallet.balance_changed.disconnect(_on_balance_changed)


func _on_balance_changed(new_balance: int, _delta: int, _reason: String) -> void:
	_refresh(new_balance)


func _refresh(value: int) -> void:
	var value_text := _format_credit_value(value)
	text = "%s%s" % [prefix, value_text]


func _format_credit_value(value: int) -> String:
	var result := str(max(value, 0))

	if zero_pad_digits > 0:
		result = result.pad_zeros(zero_pad_digits)

	if use_separator:
		result = _add_thousands_separator(result)

	return result


func _add_thousands_separator(source: String) -> String:
	var result := ""
	var count := 0

	for i in range(source.length() - 1, -1, -1):
		result = source[i] + result
		count += 1

		if count % 3 == 0 and i != 0:
			result = "," + result

	return result
