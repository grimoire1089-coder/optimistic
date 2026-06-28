extends Resource
class_name NeedInstance

signal value_changed(need_id: StringName, old_value: float, new_value: float)

@export var definition: NeedDefinition
@export var value: float = 100.0
@export var enabled: bool = true

func setup(def: NeedDefinition) -> void:
	definition = def
	if definition == null:
		value = 0.0
		return
	value = definition.get_clamped_start_value()

func tick(game_minutes: float) -> void:
	if not enabled:
		return
	if definition == null:
		return
	if game_minutes <= 0.0:
		return
	set_value(value - definition.decay_per_game_minute * game_minutes)

func set_value(new_value: float) -> void:
	if definition == null:
		return
	var old_value := value
	value = clampf(new_value, 0.0, definition.max_value)
	if is_equal_approx(old_value, value):
		return
	value_changed.emit(definition.need_id, old_value, value)

func add(amount: float) -> void:
	set_value(value + amount)

func fill() -> void:
	if definition == null:
		return
	set_value(definition.max_value)

func get_ratio() -> float:
	if definition == null:
		return 0.0
	if definition.max_value <= 0.0:
		return 0.0
	return clampf(value / definition.max_value, 0.0, 1.0)

func get_state() -> StringName:
	if definition == null:
		return &"none"
	return definition.get_state(value)

func is_low() -> bool:
	return definition != null and definition.is_low(value)

func is_critical() -> bool:
	return definition != null and definition.is_critical(value)
