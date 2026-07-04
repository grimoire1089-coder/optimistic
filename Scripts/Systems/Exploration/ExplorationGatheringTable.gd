extends Resource
class_name ExplorationGatheringTable

@export var item_paths: PackedStringArray = PackedStringArray()
@export_range(1, 99, 1) var amount_min: int = 1
@export_range(1, 99, 1) var amount_max: int = 3


func is_empty() -> bool:
	return item_paths.is_empty()


func get_safe_amount_min() -> int:
	return maxi(amount_min, 1)


func get_safe_amount_max() -> int:
	return maxi(amount_max, get_safe_amount_min())


func get_random_item_path(rng: RandomNumberGenerator) -> String:
	if item_paths.is_empty():
		return ""
	var safe_rng := rng
	if safe_rng == null:
		safe_rng = RandomNumberGenerator.new()
		safe_rng.randomize()
	return String(item_paths[safe_rng.randi_range(0, item_paths.size() - 1)])


func get_random_amount(rng: RandomNumberGenerator) -> int:
	var safe_rng := rng
	if safe_rng == null:
		safe_rng = RandomNumberGenerator.new()
		safe_rng.randomize()
	return safe_rng.randi_range(get_safe_amount_min(), get_safe_amount_max())
