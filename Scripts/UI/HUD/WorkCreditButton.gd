extends Button
class_name WorkCreditButton

@export var reward_amount: int = 25
@export var reward_reason: String = "work_button"
@export var cooldown_seconds: float = 1.0
@export var label_text: String = "仕事"

var _cooldown_left: float = 0.0


func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh_label()


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	disabled = _cooldown_left > 0.0
	_refresh_label()


func _on_pressed() -> void:
	if _cooldown_left > 0.0:
		return

	var added := CreditWallet.add(reward_amount, reward_reason)
	if not added:
		return

	_cooldown_left = cooldown_seconds
	disabled = true
	_refresh_label()


func _refresh_label() -> void:
	if _cooldown_left > 0.0:
		text = "%s\n+%d CR\n%.1fs" % [label_text, reward_amount, _cooldown_left]
		return

	disabled = false
	text = "%s\n+%d CR" % [label_text, reward_amount]
