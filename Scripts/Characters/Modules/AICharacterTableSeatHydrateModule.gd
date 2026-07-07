extends AICharacterHydrateBehaviorModule
class_name AICharacterTableSeatHydrateModule

const HydrateInventoryResolver := preload("res://Scripts/Characters/Modules/AICharacterHydrateInventoryResolver.gd")
const HydrateInventoryActions := preload("res://Scripts/Characters/Modules/AICharacterHydrateInventoryActions.gd")

const CHAIR_CLAIMED_BY_META := &"ai_seat_reserved_by"
const CHAIR_CLAIMED_NAME_META := &"ai_seat_reserved_name"
const CHAIR_CLAIMED_REASON_META := &"ai_seat_reserved_reason"

@export var legacy_inventory_module_path: NodePath = NodePath("../RobinInventoryModule")

var _shared_inventory_module: Node


func _exit_tree() -> void:
	_clear_chair_claim(_target_dining_seat)


func _resolve_refs() -> void:
	super._resolve_refs()
	_resolve_shared_inventory_module()


func _create_water_bottle_for_drinking() -> FoodItemData:
	var food_data := _get_water_bottle_item()
	if food_data == null:
		return null
	var inventory := _resolve_shared_inventory_module()
	if inventory == null:
		return null
	if not HydrateInventoryActions.add_food(inventory, food_data, 1):
		return null
	_record_bill_water_usage(1, "hydrate_refill")
	return food_data


func _has_water_bottle(food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	var inventory := _resolve_shared_inventory_module()
	return HydrateInventoryActions.has_food(inventory, food_data)


func _consume_water_bottle(food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	var inventory := _resolve_shared_inventory_module()
	if not HydrateInventoryActions.remove_food(inventory, food_data, 1):
		return false
	_apply_water_bottle_need_effect(food_data)
	return true


func _resolve_shared_inventory_module() -> Node:
	if _shared_inventory_module != null and is_instance_valid(_shared_inventory_module):
		return _shared_inventory_module
	_shared_inventory_module = HydrateInventoryResolver.resolve_inventory(
		self,
		_body,
		inventory_module_path,
		legacy_inventory_module_path
	)
	return _shared_inventory_module


func _find_best_connected_dining_seat() -> Dictionary:
	if _furniture_root == null or _room_map == null or _body == null:
		return {}
	var chairs: Array[Node2D] = []
	var tables: Array[Node2D] = []
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null or not furniture.has_meta("grid_position"):
			continue
		if AICharacterDiningSeatHelper.is_table_furniture(furniture):
			tables.append(furniture)
		elif AICharacterDiningSeatHelper.is_chair_furniture(furniture) and _can_use_chair(furniture):
			chairs.append(furniture)
	var best: Dictionary = {}
	var best_score := INF
	for chair in chairs:
		var chair_cell := AICharacterDiningSeatHelper.get_furniture_grid_position(chair)
		if not AICharacterDiningSeatHelper.is_valid_grid_position(chair_cell):
			continue
		var connected_table := AICharacterDiningSeatHelper.find_connected_table_for_chair(chair, tables, dining_minimum_overlap_cells)
		if connected_table == null:
			continue
		var use_cell := AICharacterDiningSeatHelper.get_chair_use_cell(
			_room_map,
			chair,
			_get_actor_grid_footprint(),
			Callable(self, "_is_target_cell_walkable"),
			false
		)
		if not AICharacterDiningSeatHelper.is_valid_grid_position(use_cell):
			continue
		var use_position := _room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())
		var score := _body.global_position.distance_squared_to(use_position)
		if best.is_empty() or score < best_score:
			best_score = score
			best = {
				"chair": chair,
				"table": connected_table,
				"use_cell": use_cell,
				"chair_cell": chair_cell,
				"chair_footprint": AICharacterDiningSeatHelper.get_furniture_footprint(chair),
				"table_cell": AICharacterDiningSeatHelper.get_furniture_grid_position(connected_table),
				"table_footprint": AICharacterDiningSeatHelper.get_furniture_footprint(connected_table),
			}
	return best


func _has_valid_dining_seat_target() -> bool:
	if not super._has_valid_dining_seat_target():
		return false
	return _can_use_chair(_target_dining_seat)


func _set_dining_seat_target(info: Dictionary) -> void:
	var previous_chair := _target_dining_seat
	super._set_dining_seat_target(info)
	if previous_chair != _target_dining_seat:
		_clear_chair_claim(previous_chair)
	_claim_current_chair()


func _clear_dining_seat_target() -> void:
	_clear_chair_claim(_target_dining_seat)
	super._clear_dining_seat_target()


func _lock_dining_seat_if_needed() -> void:
	super._lock_dining_seat_if_needed()
	_clear_chair_claim(_target_dining_seat)


func _can_use_chair(chair: Node2D) -> bool:
	if chair == null:
		return false
	if chair.has_meta(BUILD_LOCK_META) and chair != _target_dining_seat:
		return false
	if not chair.has_meta(CHAIR_CLAIMED_BY_META):
		return true
	var claimed_by := int(chair.get_meta(CHAIR_CLAIMED_BY_META, 0))
	return claimed_by == get_instance_id()


func _claim_current_chair() -> void:
	if _target_dining_seat == null or not is_instance_valid(_target_dining_seat):
		return
	_target_dining_seat.set_meta(CHAIR_CLAIMED_BY_META, get_instance_id())
	_target_dining_seat.set_meta(CHAIR_CLAIMED_NAME_META, _body.name if _body != null else name)
	_target_dining_seat.set_meta(CHAIR_CLAIMED_REASON_META, "DiningTarget")


func _clear_chair_claim(chair: Node2D) -> void:
	if chair == null or not is_instance_valid(chair):
		return
	if not chair.has_meta(CHAIR_CLAIMED_BY_META):
		return
	var claimed_by := int(chair.get_meta(CHAIR_CLAIMED_BY_META, 0))
	if claimed_by != get_instance_id():
		return
	chair.remove_meta(CHAIR_CLAIMED_BY_META)
	if chair.has_meta(CHAIR_CLAIMED_NAME_META):
		chair.remove_meta(CHAIR_CLAIMED_NAME_META)
	if chair.has_meta(CHAIR_CLAIMED_REASON_META):
		chair.remove_meta(CHAIR_CLAIMED_REASON_META)
