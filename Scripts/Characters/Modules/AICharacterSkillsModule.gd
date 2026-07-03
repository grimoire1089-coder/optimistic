extends Node
class_name AICharacterSkillsModule

signal skill_changed(skill_id: StringName, old_level: int, new_level: int)
signal skill_experience_changed(skill_id: StringName, new_experience: int)

const SKILL_COOKING: StringName = &"cooking"
const SKILL_COOKING_DISPLAY_NAME := "料理"
const SKILL_COOKING_MAX_LEVEL := 100

@export_range(1, SKILL_COOKING_MAX_LEVEL, 1) var cooking_level: int = 1
@export_range(0, 999999, 1) var cooking_experience: int = 0
@export_range(0, SKILL_COOKING_MAX_LEVEL, 1) var cooking_experience_bonus_until_level: int = 0
@export_range(0.0, 10.0, 0.01) var cooking_experience_bonus_multiplier: float = 0.0
@export var cooking_experience_bonus_source_id: StringName = &""


func get_skill_ids() -> Array[StringName]:
	return [SKILL_COOKING]


func get_skill_display_name(skill_id: StringName) -> String:
	match skill_id:
		SKILL_COOKING:
			return SKILL_COOKING_DISPLAY_NAME
		_:
			return String(skill_id)


func get_skill_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return clampi(cooking_level, 1, SKILL_COOKING_MAX_LEVEL)
		_:
			return 0


func get_skill_max_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return SKILL_COOKING_MAX_LEVEL
		_:
			return 0


func get_skill_experience(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			return maxi(cooking_experience, 0)
		_:
			return 0


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


func set_skill_level(skill_id: StringName, level: int) -> void:
	match skill_id:
		SKILL_COOKING:
			var old_level := cooking_level
			cooking_level = clampi(level, 1, SKILL_COOKING_MAX_LEVEL)
			if old_level != cooking_level:
				skill_changed.emit(skill_id, old_level, cooking_level)


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
			"experience_bonus_multiplier": get_skill_experience_bonus_multiplier(skill_id),
			"experience_bonus_until_level": get_skill_experience_bonus_until_level(skill_id),
		})
	return rows


func apply_skill_experience_bonus(skill_id: StringName, until_level: int, bonus_multiplier: float, source_id: StringName) -> bool:
	if until_level <= 0 or bonus_multiplier <= 0.0:
		return false
	match skill_id:
		SKILL_COOKING:
			if get_skill_level(skill_id) >= until_level:
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
			skill_experience_changed.emit(skill_id, get_skill_experience(skill_id))
			return true
	return false


func get_skill_experience_bonus_multiplier(skill_id: StringName) -> float:
	match skill_id:
		SKILL_COOKING:
			if get_skill_level(skill_id) >= cooking_experience_bonus_until_level:
				return 0.0
			return maxf(cooking_experience_bonus_multiplier, 0.0)
		_:
			return 0.0


func get_skill_experience_bonus_until_level(skill_id: StringName) -> int:
	match skill_id:
		SKILL_COOKING:
			if get_skill_level(skill_id) >= cooking_experience_bonus_until_level:
				return 0
			return cooking_experience_bonus_until_level
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
	skill_experience_changed.emit(SKILL_COOKING, cooking_experience)


func _apply_experience_bonus(skill_id: StringName, amount: int) -> int:
	var multiplier := get_skill_experience_bonus_multiplier(skill_id)
	if multiplier <= 0.0:
		return amount
	var bonus := ceili(float(amount) * multiplier)
	return amount + maxi(bonus, 1)
