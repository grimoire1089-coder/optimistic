extends Node

signal encyclopedia_changed
signal food_unlocked(item_id: StringName)

const SAVE_KEY := "unlocked_food_item_ids"
const UNLOCK_NOTICE_MODULE_SCRIPT_PATH := "res://Scripts/Systems/Encyclopedia/Modules/FoodEncyclopediaUnlockNoticeModule.gd"
const HALF_LAYOUT_MODULE_SCRIPT_PATH := "res://Scripts/UI/Encyclopedia/Modules/EncyclopediaFixedHalfLayoutModule.gd"
const ENCYCLOPEDIA_OVERLAY_GROUP := "encyclopedia_overlay"

var _unlocked_food_item_ids: Dictionary = {}
var _unlock_notice_module: Node
var _half_layout_module: Node


func _ready() -> void:
	_get_half_layout_module()
	_prepare_unlock_notice_module()


func unlock_item_id(item_id: StringName, display_name: String = "") -> bool:
	if item_id == &"":
		return false
	if _unlocked_food_item_ids.has(item_id):
		return false
	_unlocked_food_item_ids[item_id] = true
	food_unlocked.emit(item_id)
	_emit_encyclopedia_changed_if_visible()
	_notify_unlock_notice(item_id, display_name)
	return true


func register_food_discovered(item_id: StringName, display_name: String = "") -> bool:
	return unlock_item_id(item_id, display_name)


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
	_emit_encyclopedia_changed_if_visible()


func _emit_encyclopedia_changed_if_visible() -> void:
	if not _has_visible_encyclopedia_overlay():
		return
	encyclopedia_changed.emit()


func _has_visible_encyclopedia_overlay() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(ENCYCLOPEDIA_OVERLAY_GROUP):
		var canvas_item := node as CanvasItem
		if canvas_item != null and canvas_item.visible:
			return true
	return false


func _notify_unlock_notice(item_id: StringName, display_name: String) -> void:
	var module := _get_unlock_notice_module()
	if module == null or not module.has_method("push_food_unlock_notice"):
		return
	module.call("push_food_unlock_notice", item_id, display_name)


func _prepare_unlock_notice_module() -> void:
	var module := _get_unlock_notice_module()
	if module == null or not module.has_method("prepare_runtime_cache"):
		return
	module.call("prepare_runtime_cache")


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


func _get_half_layout_module() -> Node:
	if _half_layout_module != null and is_instance_valid(_half_layout_module):
		return _half_layout_module
	if not ResourceLoader.exists(HALF_LAYOUT_MODULE_SCRIPT_PATH):
		return null
	var script := load(HALF_LAYOUT_MODULE_SCRIPT_PATH) as Script
	if script == null:
		return null
	var module := script.new() as Node
	if module == null:
		return null
	module.name = "EncyclopediaFixedHalfLayoutModule"
	add_child(module)
	_half_layout_module = module
	return _half_layout_module
