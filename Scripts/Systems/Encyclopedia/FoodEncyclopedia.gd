extends Node

signal encyclopedia_changed
signal food_unlocked(item_id: StringName)

const SAVE_KEY := "unlocked_food_item_ids"
const UNLOCK_NOTICE_MODULE_SCRIPT_PATH := "res://Scripts/Systems/Encyclopedia/Modules/FoodEncyclopediaUnlockNoticeModule.gd"
const SPLIT_BALANCER_SCRIPT_PATH := "res://Scripts/UI/Encyclopedia/Modules/EncyclopediaSplitBalancer.gd"

var _unlocked_food_item_ids: Dictionary = {}
var _unlock_notice_module: Node
var _split_balancer_module: Node


func _ready() -> void:
	_get_split_balancer_module()


func unlock_item_id(item_id: StringName, display_name: String = "") -> bool:
	if item_id == &"":
		return false
	if _unlocked_food_item_ids.has(item_id):
		return false
	_unlocked_food_item_ids[item_id] = true
	food_unlocked.emit(item_id)
	encyclopedia_changed.emit()
	_notify_unlock_notice(item_id, display_name)
	return true


func unlock_food_item(food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	return unlock_item_id(food_data.item_id, food_data.display_name)


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


func _notify_unlock_notice(item_id: StringName, display_name: String) -> void:
	var module := _get_unlock_notice_module()
	if module == null or not module.has_method("push_food_unlock_notice"):
		return
	module.call("push_food_unlock_notice", item_id, display_name)


func _get_unlock_notice_module() -> Node:
	if _unlock_notice_module != null and is_instance_valid(_unlock_notice_module):
		return _unlock_notice_module
	if not ResourceLoader.exists(UNLOCK_NOTICE_MODULE_SCRIPT_PATH):
		return null
	var script := load(UNLOCK_NOTICE_MODULE_SCRIPT_PATH) as Script
	if script == null:
		return null
	var module := script.new() as Node
	if module == null:
		return null
	module.name = "FoodEncyclopediaUnlockNoticeModule"
	add_child(module)
	_unlock_notice_module = module
	return _unlock_notice_module


func _get_split_balancer_module() -> Node:
	if _split_balancer_module != null and is_instance_valid(_split_balancer_module):
		return _split_balancer_module
	if not ResourceLoader.exists(SPLIT_BALANCER_SCRIPT_PATH):
		return null
	var script := load(SPLIT_BALANCER_SCRIPT_PATH) as Script
	if script == null:
		return null
	var module := script.new() as Node
	if module == null:
		return null
	module.name = "EncyclopediaSplitBalancer"
	add_child(module)
	_split_balancer_module = module
	return _split_balancer_module
