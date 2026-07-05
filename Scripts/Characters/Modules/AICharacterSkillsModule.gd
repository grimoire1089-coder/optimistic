extends Node
class_name AICharacterSkillsModule

signal skill_changed(skill_id: StringName, old_level: int, new_level: int)
signal skill_experience_changed(skill_id: StringName, new_experience: int)
signal skill_points_changed(skill_id: StringName, available_points: int, spent_points: int)
signal skill_upgrade_changed(upgrade_id: StringName, skill_id: StringName, old_level: int, new_level: int)

const SKILL_COOKING: StringName = &"cooking"
const SKILL_COOKING_DISPLAY_NAME := "料理"
const SKILL_COOKING_MAX_LEVEL := 100
const SKILL_GATHERING: StringName = &"gathering"
const SKILL_GATHERING_DISPLAY_NAME := "採取"
const SKILL_GATHERING_MAX_LEVEL := 100

const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS: StringName = &"gathering_amount_plus"
const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_DISPLAY_NAME := "採取量＋1"
const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_DESCRIPTION := "1レベルごとに、探索での採取数が10％の確率で＋1されます。"
const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_MAX_LEVEL := 10
const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_COST := 1

@export_range(1, SKILL_COOKING_MAX_LEVEL, 1) var cooking_level: int = 1
@export_range(0, 999999, 1) var cooking_experience: int = 0
@export_range(0, SKILL_COOKING_MAX_LEVEL, 1) var cooking_spent_skill_points: int = 0
@export_range(0, SKILL_COOKING_MAX_LEVEL, 1) var cooking_experience_bonus_until_level: int = 0
@export_range(0.0, 10.0, 0.01) var cooking_experience_bonus_multiplier: float = 0.0
@export var cooking_experience_bonus_source_id: StringName = &""
@export_range(1, SKILL_GATHERING_MAX_LEVEL, 1) var gathering_level: int = 1
@export_range(0, 999999, 1) var gathering_experience: int = 0
@export_range(0, SKILL_GATHERING_MAX_LEVEL, 1) var gathering_spent_skill_points: int = 0
@export_range(0, SKILL_GATHERING_MAX_LEVEL, 1) var gathering_experience_bonus_until_level: int = 0
@export_range(0.0, 10.0, 0.01) var gathering_experience_bonus_multiplier: float = 0.0
@export var gathering_experience_bonus_source_id: StringName = &""
@export_range(0, SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_MAX_LEVEL, 1) var gathering_amount_plus_level: int = 0


func get_skill_ids() -> Array[StringName]:
	return [SKILL_COOKING, SKILL_GATHERING]


func get_skill_display_name(skill_id: StringName) -> String:
	match skill_id:
		SKILL_COOKING:
			return SKILL_COOKING_DISPLAY_NAME
		SKILL_GATHERING:
			return SKILL_GATHERING_DISPLAY_NAME
		_:
			return String(skill_id)


func get_skill_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return clampi(cooking_level, 1, SKILL_COOKING_MAX_LEVEL)
		SKILL_GATHERING:
			return clampi(gathering_level, 1, SKILL_GATHERING_MAX_LEVEL)
		_:
			return 0


func get_skill_max_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return SKILL_COOKING_MAX_LEVEL
		SKILL_GATHERING:
			return SKILL_GATHERING_MAX_LEVEL
		_:
			return 0


func get_skill_experience(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return maxi(cooking_experience, 0)
		SKILL_GATHERING:
			return maxi(gathering_experience, 0)
		_:
			return 0


func get_spent_skill_points(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return clampi(cooking_spent_skill_points, 0, get_skill_level(SKILL_COOKING))
		SKILL_GATHERING:
			return clampi(gathering_spent_skill_points, 0, get_skill_level(SKILL_GATHERING))
		_:
			return 0


func get_skill_points(skill_id: StringName) -> int:
	return maxi(get_skill_level(skill_id) - get_spent_skill_points(skill_id), 0)


func can_spend_skill_points(skill_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	return get_skill_points(skill_id) >= amount


func spend_skill_point(skill_id: StringName) -> bool:
	return spend_skill_points(skill_id, 1)


func spend_skill_points(skill_id: StringName, amount: int = 1) -> bool:
	if not can_spend_skill_points(skill_id, amount):
		return false
	match skill_id:
		SKILL_COOKING:
			cooking_spent_skill_points = clampi(
				get_spent_skill_points(skill_id) + amount,
				0,
				get_skill_level(skill_id)
			)
		SKILL_GATHERING:
			gathering_spent_skill_points = clampi(
				get_spent_skill_points(skill_id) + amount,
				0,
				get_skill_level(skill_id)
			)
		_:
			return false
	_emit_skill_points_changed(skill_id)
	return true


func refund_skill_points(skill_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var spent_points := get_spent_skill_points(skill_id)
	if spent_points <= 0:
		return false
	var refund_amount := mini(amount, spent_points)
	match skill_id:
		SKILL_COOKING:
			cooking_spent_skill_points = spent_points - refund_amount
		SKILL_GATHERING:
			gathering_spent_skill_points = spent_points - refund_amount
		_:
			return false
	_emit_skill_points_changed(skill_id)
	return true


func get_required_experience_for_next_level(skill_id: StringName) -> int:
	var level := get_skill_level(skill_id)
	var max_level := get_skill_max_level(skill_id)
	if level <= 0 or level >= max_level:
		return 0
	return level * 10


func add_skill_experience(skill_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var effective_amount := _apply_experience_bonus(skill_id, amount)
	match skill_id:
		SKILL_COOKING:
			_add_cooking_experience(effective_amount)
		SKILL_GATHERING:
			_add_gathering_experience(effective_amount)


func set_skill_level(skill_id: StringName, level: int) -> void:
	match skill_id:
		SKILL_COOKING:
			var old_cooking_level := cooking_level
			cooking_level = clampi(level, 1, SKILL_COOKING_MAX_LEVEL)
			cooking_spent_skill_points = get_spent_skill_points(skill_id)
			if old_cooking_level != cooking_level:
				skill_changed.emit(skill_id, old_cooking_level, cooking_level)
				_emit_skill_points_changed(skill_id)
		SKILL_GATHERING:
			var old_gathering_level := gathering_level
			gathering_level = clampi(level, 1, SKILL_GATHERING_MAX_LEVEL)
			gathering_spent_skill_points = get_spent_skill_points(skill_id)
			if old_gathering_level != gathering_level:
				skill_changed.emit(skill_id, old_gathering_level, gathering_level)
				_emit_skill_points_changed(skill_id)


func get_skill_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for skill_id in get_skill_ids():
		rows.append({
			"id": skill_id,
			"display_name": get_skill_display_name(skill_id),
			"level": get_skill_level(skill_id),
			"max_level": get_skill_max_level(skill_id),
			"experience": get_skill_experience(skill_id),
			"next_level_experience": get_required_experience_for_next_level(skill_id),
			"skill_points": get_skill_points(skill_id),
			"spent_skill_points": get_spent_skill_points(skill_id),
			"experience_bonus_multiplier": get_skill_experience_bonus_multiplier(skill_id),
			"experience_bonus_until_level": get_skill_experience_bonus_until_level(skill_id),
		})
	return rows


func get_skill_upgrade_ids(skill_id: StringName) -> Array[StringName]:
	match skill_id:
		SKILL_GATHERING:
			return [SKILL_UPGRADE_GATHERING_AMOUNT_PLUS]
		_:
			return []


func get_skill_upgrade_rows(skill_id: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for upgrade_id in get_skill_upgrade_ids(skill_id):
		var level := get_skill_upgrade_level(upgrade_id)
		var max_level := get_skill_upgrade_max_level(upgrade_id)
		var cost := get_skill_upgrade_cost(upgrade_id)
		rows.append({
			"id": upgrade_id,
			"skill_id": get_skill_upgrade_owner_skill_id(upgrade_id),
			"display_name": get_skill_upgrade_display_name(upgrade_id),
			"description": get_skill_upgrade_description(upgrade_id),
			"level": level,
			"max_level": max_level,
			"cost": cost,
			"can_acquire": can_acquire_skill_upgrade(upgrade_id),
			"is_max_level": level >= max_level,
		})
	return rows


func get_skill_upgrade_owner_skill_id(upgrade_id: StringName) -> StringName:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return SKILL_GATHERING
		_:
			return &""


func get_skill_upgrade_display_name(upgrade_id: StringName) -> String:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_DISPLAY_NAME
		_:
			return String(upgrade_id)


func get_skill_upgrade_description(upgrade_id: StringName) -> String:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_DESCRIPTION
		_:
			return ""


func get_skill_upgrade_level(upgrade_id: StringName) -> int:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return clampi(gathering_amount_plus_level, 0, SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_MAX_LEVEL)
		_:
			return 0


func get_skill_upgrade_max_level(upgrade_id: StringName) -> int:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_MAX_LEVEL
		_:
			return 0


func get_skill_upgrade_cost(upgrade_id: StringName) -> int:
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			return SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_COST
		_:
			return 0


func can_acquire_skill_upgrade(upgrade_id: StringName) -> bool:
	var owner_skill_id := get_skill_upgrade_owner_skill_id(upgrade_id)
	if owner_skill_id == &"":
		return false
	var cost := get_skill_upgrade_cost(upgrade_id)
	if cost <= 0:
		return false
	if get_skill_upgrade_level(upgrade_id) >= get_skill_upgrade_max_level(upgrade_id):
		return false
	return can_spend_skill_points(owner_skill_id, cost)


func acquire_skill_upgrade(upgrade_id: StringName) -> bool:
	if not can_acquire_skill_upgrade(upgrade_id):
		return false
	var owner_skill_id := get_skill_upgrade_owner_skill_id(upgrade_id)
	var cost := get_skill_upgrade_cost(upgrade_id)
	if not spend_skill_points(owner_skill_id, cost):
		return false
	match upgrade_id:
		SKILL_UPGRADE_GATHERING_AMOUNT_PLUS:
			var old_level := get_skill_upgrade_level(upgrade_id)
			gathering_amount_plus_level = clampi(old_level + 1, 0, SKILL_UPGRADE_GATHERING_AMOUNT_PLUS_MAX_LEVEL)
			skill_upgrade_changed.emit(upgrade_id, owner_skill_id, old_level, gathering_amount_plus_level)
			return true
		_:
			return false


func get_gathering_amount_plus_level() -> int:
	return get_skill_upgrade_level(SKILL_UPGRADE_GATHERING_AMOUNT_PLUS)


func get_gathering_amount_plus_chance() -> float:
	return clampf(float(get_gathering_amount_plus_level()) * 0.10, 0.0, 1.0)


func apply_skill_experience_bonus(skill_id: StringName, until_level: int, bonus_multiplier: float, source_id: StringName) -> bool:
	if until_level <= 0 or bonus_multiplier <= 0.0:
		return false
	match skill_id:
		SKILL_COOKING:
			return _apply_cooking_experience_bonus(until_level, bonus_multiplier, source_id)
		SKILL_GATHERING:
			return _apply_gathering_experience_bonus(until_level, bonus_multiplier, source_id)
	return false


func get_skill_experience_bonus_multiplier(skill_id: StringName) -> float:
	match skill_id:
		SKILL_COOKING:
			if get_skill_level(skill_id) >= cooking_experience_bonus_until_level:
				return 0.0
			return maxf(cooking_experience_bonus_multiplier, 0.0)
		SKILL_GATHERING:
			if get_skill_level(skill_id) >= gathering_experience_bonus_until_level:
				return 0.0
			return maxf(gathering_experience_bonus_multiplier, 0.0)
		_:
			return 0.0


func get_skill_experience_bonus_until_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			if get_skill_level(skill_id) >= cooking_experience_bonus_until_level:
				return 0
			return cooking_experience_bonus_until_level
		SKILL_GATHERING:
			if get_skill_level(skill_id) >= gathering_experience_bonus_until_level:
				return 0
			return gathering_experience_bonus_until_level
		_:
			return 0


func _add_cooking_experience(amount: int) -> void:
	if cooking_level >= SKILL_COOKING_MAX_LEVEL:
		cooking_level = SKILL_COOKING_MAX_LEVEL
		cooking_experience = 0
		skill_experience_changed.emit(SKILL_COOKING, cooking_experience)
		return

	var old_level := cooking_level
	cooking_experience += amount
	while cooking_level < SKILL_COOKING_MAX_LEVEL:
		var required_experience := get_required_experience_for_next_level(SKILL_COOKING)
		if required_experience <= 0 or cooking_experience < required_experience:
			break
		cooking_experience -= required_experience
		cooking_level += 1

	if cooking_level >= SKILL_COOKING_MAX_LEVEL:
		cooking_level = SKILL_COOKING_MAX_LEVEL
		cooking_experience = 0

	if old_level != cooking_level:
		skill_changed.emit(SKILL_COOKING, old_level, cooking_level)
		_emit_skill_points_changed(SKILL_COOKING)
	skill_experience_changed.emit(SKILL_COOKING, cooking_experience)


func _add_gathering_experience(amount: int) -> void:
	if gathering_level >= SKILL_GATHERING_MAX_LEVEL:
		gathering_level = SKILL_GATHERING_MAX_LEVEL
		gathering_experience = 0
		skill_experience_changed.emit(SKILL_GATHERING, gathering_experience)
		return

	var old_level := gathering_level
	gathering_experience += amount
	while gathering_level < SKILL_GATHERING_MAX_LEVEL:
		var required_experience := get_required_experience_for_next_level(SKILL_GATHERING)
		if required_experience <= 0 or gathering_experience < required_experience:
			break
		gathering_experience -= required_experience
		gathering_level += 1

	if gathering_level >= SKILL_GATHERING_MAX_LEVEL:
		gathering_level = SKILL_GATHERING_MAX_LEVEL
		gathering_experience = 0

	if old_level != gathering_level:
		skill_changed.emit(SKILL_GATHERING, old_level, gathering_level)
		_emit_skill_points_changed(SKILL_GATHERING)
	skill_experience_changed.emit(SKILL_GATHERING, gathering_experience)


func _apply_cooking_experience_bonus(until_level: int, bonus_multiplier: float, source_id: StringName) -> bool:
	if get_skill_level(SKILL_COOKING) >= until_level:
		return false
	var safe_until_level := clampi(until_level, 1, SKILL_COOKING_MAX_LEVEL)
	var safe_multiplier := maxf(bonus_multiplier, 0.0)
	var should_replace := cooking_experience_bonus_source_id == source_id
	should_replace = should_replace or safe_until_level > cooking_experience_bonus_until_level
	should_replace = should_replace or (
		safe_until_level == cooking_experience_bonus_until_level
		and safe_multiplier > cooking_experience_bonus_multiplier
	)
	if not should_replace:
		return false
	cooking_experience_bonus_until_level = safe_until_level
	cooking_experience_bonus_multiplier = safe_multiplier
	cooking_experience_bonus_source_id = source_id
	skill_experience_changed.emit(SKILL_COOKING, get_skill_experience(SKILL_COOKING))
	return true


func _apply_gathering_experience_bonus(until_level: int, bonus_multiplier: float, source_id: StringName) -> bool:
	if get_skill_level(SKILL_GATHERING) >= until_level:
		return false
	var safe_until_level := clampi(until_level, 1, SKILL_GATHERING_MAX_LEVEL)
	var safe_multiplier := maxf(bonus_multiplier, 0.0)
	var should_replace := gathering_experience_bonus_source_id == source_id
	should_replace = should_replace or safe_until_level > gathering_experience_bonus_until_level
	should_replace = should_replace or (
		safe_until_level == gathering_experience_bonus_until_level
		and safe_multiplier > gathering_experience_bonus_multiplier
	)
	if not should_replace:
		return false
	gathering_experience_bonus_until_level = safe_until_level
	gathering_experience_bonus_multiplier = safe_multiplier
	gathering_experience_bonus_source_id = source_id
	skill_experience_changed.emit(SKILL_GATHERING, get_skill_experience(SKILL_GATHERING))
	return true


func _apply_experience_bonus(skill_id: StringName, amount: int) -> int:
	var multiplier := get_skill_experience_bonus_multiplier(skill_id)
	if multiplier <= 0.0:
		return amount
	var bonus := ceili(float(amount) * multiplier)
	return amount + maxi(bonus, 1)


func _emit_skill_points_changed(skill_id: StringName) -> void:
	skill_points_changed.emit(skill_id, get_skill_points(skill_id), get_spent_skill_points(skill_id))
