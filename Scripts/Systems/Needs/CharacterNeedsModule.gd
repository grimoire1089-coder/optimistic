extends Node
class_name CharacterNeedsModule

signal need_changed(need_id: StringName, old_value: float, new_value: float)
signal need_became_low(need_id: StringName)
signal need_became_critical(need_id: StringName)

@export var character_needs: CharacterNeeds
@export var definitions: Array[NeedDefinition] = []
@export var process_fallback_enabled: bool = false
@export var fallback_game_minutes_per_second: float = 1.0
@export var load_default_definitions_on_ready: bool = true

func _ready() -> void:
	_ensure_character_needs()
	_connect_character_needs()
	set_process(process_fallback_enabled)

func _process(delta: float) -> void:
	if process_fallback_enabled:
		tick_game_minutes(delta * fallback_game_minutes_per_second)

func setup_with_definitions(new_definitions: Array) -> void:
	definitions.clear()
	for def in new_definitions:
		if def != null and def is NeedDefinition:
			definitions.append(def)
	character_needs = CharacterNeeds.new()
	character_needs.setup_from_definitions(definitions)
	_connect_character_needs()

func tick_game_minutes(game_minutes: float) -> void:
	_ensure_character_needs()
	character_needs.tick(game_minutes)

func get_character_needs() -> CharacterNeeds:
	_ensure_character_needs()
	return character_needs

func get_need(need_id: StringName) -> NeedInstance:
	_ensure_character_needs()
	return character_needs.get_need(need_id)

func get_need_value(need_id: StringName, fallback: float = 0.0) -> float:
	_ensure_character_needs()
	return character_needs.get_need_value(need_id, fallback)

func get_need_ratio(need_id: StringName, fallback: float = 0.0) -> float:
	_ensure_character_needs()
	return character_needs.get_need_ratio(need_id, fallback)

func add_need_value(need_id: StringName, amount: float) -> void:
	_ensure_character_needs()
	character_needs.add_need_value(need_id, amount)

func set_need_value(need_id: StringName, new_value: float) -> void:
	_ensure_character_needs()
	character_needs.set_need_value(need_id, new_value)

func fill_need(need_id: StringName) -> void:
	_ensure_character_needs()
	character_needs.fill_need(need_id)

func apply_recovery(recovery_by_need_id: Dictionary) -> void:
	_ensure_character_needs()
	character_needs.apply_recovery(recovery_by_need_id)

func get_lowest_need() -> NeedInstance:
	_ensure_character_needs()
	return character_needs.get_lowest_need()

func get_lowest_need_id() -> StringName:
	_ensure_character_needs()
	return character_needs.get_lowest_need_id()

func get_need_priority(need_id: StringName) -> float:
	_ensure_character_needs()
	return character_needs.get_need_priority(need_id)

func set_process_fallback_enabled(enabled: bool) -> void:
	process_fallback_enabled = enabled
	set_process(process_fallback_enabled)

func _ensure_character_needs() -> void:
	if character_needs != null:
		return
	character_needs = CharacterNeeds.new()
	if definitions.is_empty() and load_default_definitions_on_ready:
		_load_default_definitions()
	character_needs.setup_from_definitions(definitions)

func _load_default_definitions() -> void:
	definitions.clear()
	for path in CharacterNeedIds.get_default_definition_paths():
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource != null and resource is NeedDefinition:
				definitions.append(resource)

func _connect_character_needs() -> void:
	if character_needs == null:
		return
	var changed_callable := Callable(self, "_on_need_changed")
	if not character_needs.need_changed.is_connected(changed_callable):
		character_needs.need_changed.connect(changed_callable)
	var low_callable := Callable(self, "_on_need_became_low")
	if not character_needs.need_became_low.is_connected(low_callable):
		character_needs.need_became_low.connect(low_callable)
	var critical_callable := Callable(self, "_on_need_became_critical")
	if not character_needs.need_became_critical.is_connected(critical_callable):
		character_needs.need_became_critical.connect(critical_callable)

func _on_need_changed(need_id: StringName, old_value: float, new_value: float) -> void:
	need_changed.emit(need_id, old_value, new_value)

func _on_need_became_low(need_id: StringName) -> void:
	need_became_low.emit(need_id)

func _on_need_became_critical(need_id: StringName) -> void:
	need_became_critical.emit(need_id)
