extends Resource
class_name ExplorationGatheringTable

@export var item_paths: PackedStringArray = PackedStringArray()
@export var required_skill_levels: PackedInt32Array = PackedInt32Array()
@export_range(1, 99, 1) var amount_min: int = 1
@export_range(1, 99, 1) var amount_max: int = 3


func is_empty() -> bool:
	return item_paths.is_empty()


func is_empty_for_skill(skill_level: int) -> bool:
	return get_available_item_indices(skill_level).is_empty()


func get_safe_amount_min() -> int:
	return maxi(amount_min, 1)


func get_safe_amount_max() -> int:
	return maxi(amount_max, get_safe_amount_min())


func get_required_skill_level_for_index(index: int) -> int:
	if index < 0 or index >= item_paths.size():
		return 999999
	if index < required_skill_levels.size():
		return maxi(required_skill_levels[index], 1)
	return 1


func get_available_item_indices(skill_level: int) -> Array[int]:
	var result: Array[int] = []
	var safe_level := maxi(skill_level, 1)
	for index in range(item_paths.size()):
		if String(item_paths[index]).is_empty():
			continue
		if safe_level < get_required_skill_level_for_index(index):
			continue
		result.append(index)
	return result


func get_random_item_path(rng: RandomNumberGenerator) -> String:
	return get_random_item_path_for_skill(rng, 999999)


func get_random_item_path_for_skill(rng: RandomNumberGenerator, skill_level: int) -> String:
	var available_indices := get_available_item_indices(skill_level)
	if available_indices.is_empty():
		return ""
	var safe_rng := rng
	if safe_rng == null:
		safe_rng = RandomNumberGenerator.new()
		safe_rng.randomize()
	var index := available_indices[safe_rng.randi_range(0, available_indices.size() - 1)]
	return String(item_paths[index])


func get_required_skill_level_for_item_path(item_path: String) -> int:
	for index in range(item_paths.size()):
		if String(item_paths[index]) == item_path:
			return get_required_skill_level_for_index(index)
	return 1


func get_random_amount(rng: RandomNumberGenerator) -> int:
	var safe_rng := rng
	if safe_rng == null:
		safe_rng = RandomNumberGenerator.new()
		safe_rng.randomize()
	return safe_rng.randi_range(get_safe_amount_min(), get_safe_amount_max())
