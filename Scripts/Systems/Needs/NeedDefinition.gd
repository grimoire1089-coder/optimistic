extends Resource
class_name NeedDefinition

@export var need_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var max_value: float = 100.0
@export var start_value: float = 100.0

# 1ゲーム分あたりの減少量。
# GameClock側から分単位で tick_game_minutes() を呼ぶ想定です。
@export var decay_per_game_minute: float = 0.01

@export var low_threshold: float = 30.0
@export var critical_threshold: float = 10.0

# ムード・会話・AI行動に接続するための任意IDです。
@export var low_mood_id: StringName = &""
@export var critical_mood_id: StringName = &""
@export var recovery_action_id: StringName = &""

func get_clamped_start_value() -> float:
	return clampf(start_value, 0.0, max_value)

func is_low(value: float) -> bool:
	return value <= low_threshold

func is_critical(value: float) -> bool:
	return value <= critical_threshold

func get_state(value: float) -> StringName:
	if is_critical(value):
		return &"critical"
	if is_low(value):
		return &"low"
	return &"normal"
