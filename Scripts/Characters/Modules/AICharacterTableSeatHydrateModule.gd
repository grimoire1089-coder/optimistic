extends AICharacterHydrateBehaviorModule
class_name AICharacterTableSeatHydrateModule

const HydrateInventoryResolver := preload("res://Scripts/Characters/Modules/AICharacterHydrateInventoryResolver.gd")
const HydrateInventoryActions := preload("res://Scripts/Characters/Modules/AICharacterHydrateInventoryActions.gd")
const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

const CHAIR_CLAIMED_BY_META := &"ai_seat_reserved_by"
const CHAIR_CLAIMED_NAME_META := &"ai_seat_reserved_name"
const CHAIR_CLAIMED_REASON_META := &"ai_seat_reserved_reason"

@export var legacy_inventory_module_path: NodePath = NodePath("")
@export var action_runner_integration_enabled: bool = false
@export var action_runner_ai_actor_group_name: StringName = &"ai_character_actor"
@export var action_runner_use_shared_move_slot: bool = true

var _shared_inventory_module: Node
var _action_runner_controlled := false
var _hydrate_need_signal_source: CharacterNeedsModule
var _hydrate_need_was_requested := false


func setup(body: CharacterBody2D) -> void:
	_disconnect_hydrate_need_signal()
	super.setup(body)
	_connect_hydrate_need_signal()
	_hydrate_need_was_requested = _is_hydrate_need_requested()


func _exit_tree() -> void:
	_disconnect_hydrate_need_signal()
	cancel_action_runner_hydrate()
	_clear_chair_claim(_target_dining_seat)


func can_start_action_runner_hydrate() -> bool:
	if not action_runner_integration_enabled:
		return false
	_resolve_refs()
	if _body == null or not is_instance_valid(_body) or _needs_module == null:
		return false
	if _has_action_runner_hydrate_commitment():
		return true
	if _cooldown_timer > 0.0:
		return false
	return _should_hydrate_now()


func get_action_runner_hydrate_score() -> float:
	if _has_action_runner_hydrate_commitment():
		return 1000.0
	if _is_hydrate_need_requested():
		return 500.0
	if _should_hydrate_now():
		return 400.0
	return -INF


func start_action_runner_hydrate() -> bool:
	if not can_start_action_runner_hydrate():
		return false
	_action_runner_controlled = true
	return true


func tick_action_runner_hydrate(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		return AICharacterActionResult.completed("hydrate action finished")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_hydrate() -> void:
	_reset_action_runner_hydrate_state()
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func cleanup_action_runner_hydrate() -> void:
	if _has_action_runner_hydrate_commitment():
		_reset_action_runner_hydrate_state()
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func get_action_runner_hydrate_debug_summary() -> String:
	return "hydrate runner_controlled=%s requested=%s %s" % [
		str(_action_runner_controlled),
		str(_is_hydrate_need_requested()),
		get_debug_movement_summary(),
	]


func _has_action_runner_hydrate_commitment() -> bool:
	return (
		_action_runner_controlled
		or _is_active
		or _is_drinking
		or _pending_drink_food_data != null
		or _target_kitchen != null
		or _target_dining_seat != null
	)


func _reset_action_runner_hydrate_state() -> void:
	_is_drinking = false
	_drink_food_data = null
	_pending_drink_food_data = null
	_drink_timer = 0.0
	_drink_start_progress = 0.0
	_drink_sfx_played = false
	_action_progress_ratio = 0.0
	_finish_hydrate_action()


func _connect_hydrate_need_signal() -> void:
	if _needs_module == null:
		return
	var callable := Callable(self, "_on_hydrate_need_changed")
	if not _needs_module.need_changed.is_connected(callable):
		_needs_module.need_changed.connect(callable)
	_hydrate_need_signal_source = _needs_module


func _disconnect_hydrate_need_signal() -> void:
	if _hydrate_need_signal_source == null or not is_instance_valid(_hydrate_need_signal_source):
		_hydrate_need_signal_source = null
		return
	var callable := Callable(self, "_on_hydrate_need_changed")
	if _hydrate_need_signal_source.need_changed.is_connected(callable):
		_hydrate_need_signal_source.need_changed.disconnect(callable)
	_hydrate_need_signal_source = null


func _on_hydrate_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	if need_id != water_need_id:
		return
	var hydrate_requested := _is_hydrate_need_requested()
	var became_requested := hydrate_requested and not _hydrate_need_was_requested
	_hydrate_need_was_requested = hydrate_requested
	if not became_requested or not action_runner_integration_enabled:
		return
	var runner := _get_action_runner()
	if runner == null:
		return
	if runner.get_active_action_id() == hydrate_action_id:
		return
	runner.request_rethink("water need became actionable")


func _is_hydrate_need_requested() -> bool:
	if _needs_module == null:
		return false
	return _needs_module.get_need_ratio(water_need_id, 1.0) <= hydrate_request_ratio


func _get_action_runner() -> AICharacterActionRunner:
	if _body == null or not is_instance_valid(_body):
		return null
	if not _body.has_method("get_ai_action_runner"):
		return null
	return _body.call("get_ai_action_runner") as AICharacterActionRunner


func _can_action_runner_move_now() -> bool:
	if _body == null:
		return false
	if not action_runner_use_shared_move_slot:
		return true
	if MoveSlot.can_move(_body):
		return MoveSlot.request_move(_body)
	if MoveSlot.is_other_actor_moving(_body, action_runner_ai_actor_group_name):
		return false
	return MoveSlot.request_move(_body)


func _release_action_runner_move_slot() -> void:
	if _body == null or not action_runner_use_shared_move_slot:
		return
	MoveSlot.release_move(_body)


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
