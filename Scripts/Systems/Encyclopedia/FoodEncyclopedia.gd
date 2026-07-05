extends Node

signal encyclopedia_changed
signal food_unlocked(item_id: StringName)

const SAVE_KEY := "unlocked_food_item_ids"

var _unlocked_food_item_ids: Dictionary = {}


func unlock_item_id(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	if _unlocked_food_item_ids.has(item_id):
		return false
	_unlocked_food_item_ids[item_id] = true
	food_unlocked.emit(item_id)
	encyclopedia_changed.emit()
	return true


func unlock_food_item(food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	return unlock_item_id(food_data.item_id)


func is_item_unlocked(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	return _unlocked_food_item_ids.has(item_id)


func is_food_unlocked(food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	return is_item_unlocked(food_data.item_id)


func get_unlocked_count() -> int:
	return _unlocked_food_item_ids.size()


func get_unlocked_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_id in _unlocked_food_item_ids.keys():
		result.append(StringName(String(raw_id)))
	return result


func to_save_data() -> Dictionary:
	var ids: Array[String] = []
	for raw_id in _unlocked_food_item_ids.keys():
		ids.append(String(raw_id))
	ids.sort()
	return {
		SAVE_KEY: ids,
	}


func apply_save_data(data: Dictionary) -> void:
	_unlocked_food_item_ids.clear()
	if data.has(SAVE_KEY):
		var ids = data[SAVE_KEY]
		for raw_id in ids:
			var item_id := StringName(String(raw_id))
			if item_id != &"":
				_unlocked_food_item_ids[item_id] = true
	encyclopedia_changed.emit()
