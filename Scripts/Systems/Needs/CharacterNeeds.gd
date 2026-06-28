extends Resource
class_name CharacterNeeds

signal need_changed(need_id: StringName, old_value: float, new_value: float)
signal need_became_low(need_id: StringName)
signal need_became_critical(need_id: StringName)

@export var needs: Array[NeedInstance] = []

func setup_from_definitions(definitions: Array) -> void:
	needs.clear()
	for def in definitions:
		if def == null:
			continue
		if not def is NeedDefinition:
			continue
		var instance := NeedInstance.new()
		instance.setup(def)
		add_need_instance(instance)

func add_need_instance(instance: NeedInstance) -> void:
	if instance == null:
		return
	needs.append(instance)
	_connect_need(instance)

func tick(game_minutes: float) -> void:
	if game_minutes <= 0.0:
		return
	for need in needs:
		if need == null:
			continue
		var old_state := need.get_state()
		need.tick(game_minutes)
		var new_state := need.get_state()
		if old_state != &"critical" and new_state == &"critical":
			need_became_critical.emit(need.definition.need_id)
		elif old_state == &"normal" and new_state == &"low":
			need_became_low.emit(need.definition.need_id)

func get_need(need_id: StringName) -> NeedInstance:
	for need in needs:
		if need == null:
			continue
		if need.definition == null:
			continue
		if need.definition.need_id == need_id:
			return need
	return null

func has_need(need_id: StringName) -> bool:
	return get_need(need_id) != null

func get_need_value(need_id: StringName, fallback: float = 0.0) -> float:
	var need := get_need(need_id)
	if need == null:
		return fallback
	return need.value

func get_need_ratio(need_id: StringName, fallback: float = 0.0) -> float:
	var need := get_need(need_id)
	if need == null:
		return fallback
	return need.get_ratio()

func add_need_value(need_id: StringName, amount: float) -> void:
	var need := get_need(need_id)
	if need == null:
		return
	need.add(amount)

func set_need_value(need_id: StringName, new_value: float) -> void:
	var need := get_need(need_id)
	if need == null:
		return
	need.set_value(new_value)

func fill_need(need_id: StringName) -> void:
	var need := get_need(need_id)
	if need == null:
		return
	need.fill()

func apply_recovery(recovery_by_need_id: Dictionary) -> void:
	for need_id in recovery_by_need_id.keys():
		add_need_value(need_id, float(recovery_by_need_id[need_id]))

func get_lowest_need() -> NeedInstance:
	var lowest: NeedInstance = null
	for need in needs:
		if need == null:
			continue
		if need.definition == null:
			continue
		if lowest == null or need.get_ratio() < lowest.get_ratio():
			lowest = need
	return lowest

func get_lowest_need_id() -> StringName:
	var lowest := get_lowest_need()
	if lowest == null or lowest.definition == null:
		return &""
	return lowest.definition.need_id

func get_critical_needs() -> Array[NeedInstance]:
	var result: Array[NeedInstance] = []
	for need in needs:
		if need != null and need.is_critical():
			result.append(need)
	return result

func get_low_needs() -> Array[NeedInstance]:
	var result: Array[NeedInstance] = []
	for need in needs:
		if need != null and need.is_low():
			result.append(need)
	return result

func get_need_priority(need_id: StringName) -> float:
	var need := get_need(need_id)
	if need == null:
		return 0.0
	var priority := 1.0 - need.get_ratio()
	if need.is_critical():
		priority += 1.0
	elif need.is_low():
		priority += 0.5
	return priority

func _connect_need(need: NeedInstance) -> void:
	if need == null:
		return
	var callable := Callable(self, "_on_need_value_changed")
	if not need.value_changed.is_connected(callable):
		need.value_changed.connect(callable)

func _on_need_value_changed(need_id: StringName, old_value: float, new_value: float) -> void:
	need_changed.emit(need_id, old_value, new_value)
