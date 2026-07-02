extends Node
class_name AICharacterSkillsModule

signal skill_changed(skill_id: StringName, old_level: int, new_level: int)
signal skill_experience_changed(skill_id: StringName, new_experience: int)

const SKILL_COOKING: StringName = &"cooking"
const SKILL_COOKING_DISPLAY_NAME := "料理"
const SKILL_COOKING_MAX_LEVEL := 100

@export_range(1, SKILL_COOKING_MAX_LEVEL, 1) var cooking_level: int = 1
@export_range(0, 999999, 1) var cooking_experience: int = 0


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
	match skill_id:
		SKILL_COOKING:
			_add_cooking_experience(amount)


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
		})
	return rows


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
