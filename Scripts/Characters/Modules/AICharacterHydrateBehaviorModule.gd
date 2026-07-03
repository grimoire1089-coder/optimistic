extends Node
class_name AICharacterHydrateBehaviorModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)

@export var needs_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterNeedsModule")
@export var need_planner_path: NodePath = NodePath("../AICharacterNeedsBundle/NeedDrivenAIPlanner")
@export var inventory_module_path: NodePath = NodePath("../RobinInventoryModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var water_need_id: StringName = CharacterNeedIds.WATER
@export var hydrate_action_id: StringName = CharacterNeedActionIds.HYDRATE
@export var kitchen_module_ids: Array[StringName] = [&"kitchen_module"]
@export var water_bottle_item_path: String = "res://Data/Items/Food/Food_0008_WaterBottle.tres"
@export_range(0.0, 1.0, 0.01) var hydrate_request_ratio: float = 0.33
@export var walk_speed: float = 80.0
@export var arrival_distance: float = 8.0
@export var refill_distance: float = 14.0
@export var nearby_refill_distance: float = 52.0
@export var grid_arrival_distance: float = 6.0
@export var refill_cooldown_seconds: float = 1.5
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var apply_need_effect_after_refill: bool = true
@export var drink_duration_seconds: float = 3.0
@export var drink_sfx_path: String = "res://Assets/Audio/SFX/Game/drink.ogg"
@export var drink_sfx_delay_seconds: float = 0.75
@export var drink_sfx_volume_db: float = 0.0

var _body: CharacterBody2D
var _needs_module: CharacterNeedsModule
var _need_planner: NeedDrivenAIPlanner
var _inventory_module: RobinInventoryModule
var _furniture_root: Node
var _furniture_placement_module: Node
var _room_map: RoomMapGridModule
var _target_kitchen: Node2D
var _water_bottle_item: FoodItemData
var _drink_sfx: AudioStream
var _is_active := false
var _is_drinking := false
var _facing_direction := Vector2.DOWN
var _cooldown_timer := 0.0
var _drink_timer := 0.0
var _drink_start_progress := 0.0
var _drink_sfx_played := false
var _drink_food_data: FoodItemData
var _action_progress_ratio := 0.0
var _move_start_distance := 0.0
var _last_target_kitchen: Node2D
var _target_cell: Vector2i = INVALID_GRID_POSITION
var _target_kitchen_grid_position: Vector2i = INVALID_GRID_POSITION
var _target_kitchen_grid_footprint: Vector2i = Vector2i.ZERO
var _path_cells: Array[Vector2i] = []


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func is_active() -> bool:
	return _is_active


func is_drinking() -> bool:
	return _is_drinking


func is_action_progress_visible() -> bool:
	return _is_drinking


func get_action_progress_ratio() -> float:
	return clampf(_action_progress_ratio, 0.0, 1.0)


func is_action_item_display_visible() -> bool:
	return _is_drinking and _drink_food_data != null


func get_action_item_icon_path() -> String:
	if _drink_food_data == null:
		return ""
	return _drink_food_data.get_icon_path()


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_debug_path_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _is_drinking:
		return result
	for cell in _path_cells:
		result.append(cell)
	return result


func get_debug_target_cell() -> Vector2i:
	if _is_drinking:
		return INVALID_GRID_POSITION
	return _target_cell


func get_debug_next_cell() -> Vector2i:
	if _is_drinking:
		return INVALID_GRID_POSITION
	if _path_cells.is_empty():
		return INVALID_GRID_POSITION
	return _path_cells[0]


func get_debug_actor_footprint() -> Vector2i:
	return _get_actor_grid_footprint()


func get_debug_movement_summary() -> String:
	if _is_drinking:
		return "drinking=true path=0 footprint=%s" % [str(get_debug_actor_footprint())]
	return "target_cell=%s next_cell=%s path=%d footprint=%s" % [
		str(get_debug_target_cell()),
		str(get_debug_next_cell()),
		_path_cells.size(),
		str(get_debug_actor_footprint()),
	]


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	_tick_cooldown(delta)
	_is_active = false

	if _body == null or _needs_module == null:
		_reset_hydrate_action()
		return Vector2.ZERO

	if _is_drinking:
		_is_active = true
		_facing_direction = Vector2.DOWN
		_update_drinking(delta)
		return Vector2.ZERO

	if _cooldown_timer > 0.0:
		_reset_hydrate_action()
		return Vector2.ZERO

	if not _should_hydrate_now():
		_reset_hydrate_action()
		return Vector2.ZERO

	if _begin_existing_water_bottle_drink():
		_is_active = true
		return Vector2.ZERO

	if not _ensure_hydrate_target():
		_reset_hydrate_action()
		return Vector2.ZERO

	var target_cell: Vector2i = _target_cell
	if not _is_valid_grid_position(target_cell):
		if _is_close_enough_to_refill(_target_kitchen):
			_begin_created_water_bottle_drink()
			return Vector2.ZERO
		_finish_hydrate_action()
		return Vector2.ZERO

	_is_active = true
	var target_position := _get_kitchen_use_position_from_cell(_target_kitchen, target_cell)
	var to_target := target_position - _body.global_position
	var target_distance := to_target.length()
	_sync_movement_progress_target(target_distance)

	if target_distance <= refill_distance or _is_close_enough_to_refill(_target_kitchen):
		_begin_created_water_bottle_drink()
		return Vector2.ZERO

	var path_velocity := _get_grid_path_velocity_to_target(target_cell, target_distance)
	if path_velocity != Vector2.ZERO:
		return path_velocity

	to_target = target_position - _body.global_position
	target_distance = to_target.length()
	var can_refill_after_path_failure := target_distance <= maxf(arrival_distance, refill_distance)
	can_refill_after_path_failure = can_refill_after_path_failure or _is_close_enough_to_refill(_target_kitchen)
	can_refill_after_path_failure = can_refill_after_path_failure or _is_near_refill_target_cell(target_cell)
	if can_refill_after_path_failure:
		_begin_created_water_bottle_drink()
		return Vector2.ZERO

	_finish_hydrate_action()
	return Vector2.ZERO


func _should_hydrate_now() -> bool:
	if _needs_module == null:
		return false
	var water_ratio := _needs_module.get_need_ratio(water_need_id, 1.0)
	if water_ratio <= hydrate_request_ratio:
		return true
	if _need_planner == null:
		return false
	return _need_planner.get_next_action_id() == hydrate_action_id


func _begin_existing_water_bottle_drink() -> bool:
	var food_data := _get_water_bottle_item()
	if food_data == null:
		return false
	if not _has_water_bottle(food_data):
		return false
	_clear_hydrate_target()
	_begin_drinking(food_data, 0.0)
	return true


func _begin_created_water_bottle_drink() -> void:
	var created_food_data := _create_water_bottle_for_drinking()
	if created_food_data != null:
		_begin_drinking(created_food_data, 0.0)
	else:
		_finish_hydrate_action()


func _create_water_bottle_for_drinking() -> FoodItemData:
	var food_data := _get_water_bottle_item()
	if food_data == null:
		return null
	if _inventory_module == null:
		return null
	if not _inventory_module.add_food_item(food_data, 1):
		return null
	return food_data


func _begin_drinking(food_data: FoodItemData, start_progress: float) -> void:
	_snap_body_to_drink_grid_center()
	_drink_food_data = food_data
	_is_drinking = true
	_is_active = true
	_drink_timer = 0.0
	_drink_sfx_played = false
	_drink_start_progress = clampf(start_progress, 0.0, 0.95)
	_action_progress_ratio = _drink_start_progress
	_facing_direction = Vector2.DOWN
	_path_cells.clear()


func _snap_body_to_drink_grid_center() -> bool:
	if _body == null or _room_map == null:
		return false
	var footprint := _get_actor_grid_footprint()
	var snap_cell := _target_cell
	if not _is_target_cell_inside(snap_cell, footprint):
		snap_cell = _get_current_actor_top_left_grid_position()
	if not _is_target_cell_inside(snap_cell, footprint):
		snap_cell = _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if not _is_valid_grid_position(snap_cell):
		return false
	var snap_position := _room_map.grid_to_world_area_center(snap_cell, footprint)
	var changed := _body.global_position.distance_squared_to(snap_position) > 0.001
	_body.global_position = snap_position
	_path_cells.clear()
	return changed


func _update_drinking(delta: float) -> void:
	var duration := maxf(drink_duration_seconds, 0.1)
	_drink_timer = minf(_drink_timer + maxf(delta, 0.0), duration)
	_try_play_drink_sfx()
	var local_ratio := clampf(_drink_timer / duration, 0.0, 1.0)
	_action_progress_ratio = lerpf(_drink_start_progress, 1.0, local_ratio)
	if _drink_timer >= duration:
		_complete_drinking()


func _complete_drinking() -> void:
	var food_data := _drink_food_data
	_is_drinking = false
	_drink_food_data = null
	if food_data != null:
		_consume_water_bottle(food_data)
	_finish_hydrate_action()


func _try_play_drink_sfx() -> void:
	if _drink_sfx_played:
		return
	if _drink_timer < maxf(drink_sfx_delay_seconds, 0.0):
		return
	_drink_sfx_played = true
	var stream := _get_drink_sfx()
	if stream == null:
		return
	var audio_player := get_node_or_null("/root/AudioPlayer")
	if audio_player != null and audio_player.has_method("play_sfx"):
		audio_player.call("play_sfx", stream, 1.0, drink_sfx_volume_db)


func _get_drink_sfx() -> AudioStream:
	if _drink_sfx != null:
		return _drink_sfx
	if drink_sfx_path.is_empty():
		return null
	if not ResourceLoader.exists(drink_sfx_path):
		return null
	_drink_sfx = load(drink_sfx_path) as AudioStream
	return _drink_sfx


func _has_water_bottle(food_data: FoodItemData) -> bool:
	if _inventory_module == null or food_data == null:
		return false
	var items := _inventory_module.get_items(food_data.category_id)
	for item in items:
		if not (item is Dictionary):
			continue
		var item_data := item as Dictionary
		if item_data.get("id", &"") != food_data.item_id:
			continue
		return int(item_data.get("amount", 0)) > 0
	return false


func _consume_water_bottle(food_data: FoodItemData) -> bool:
	if _inventory_module == null or food_data == null:
		return false
	if not _inventory_module.remove_item(food_data.category_id, food_data.item_id, 1):
		return false
	_apply_water_bottle_need_effect(food_data)
	return true


func _apply_water_bottle_need_effect(food_data: FoodItemData) -> void:
	if not apply_need_effect_after_refill:
		return
	if _needs_module == null or food_data == null or food_data.need_effect == null:
		return
	for need_id in food_data.need_effect.values.keys():
		_needs_module.add_need_value(need_id, float(food_data.need_effect.values[need_id]))


func _finish_hydrate_action() -> void:
	_clear_hydrate_target()
	_move_start_distance = 0.0
	_cooldown_timer = maxf(refill_cooldown_seconds, 0.0)
	_action_progress_ratio = 0.0
	_is_active = false


func _reset_hydrate_action() -> void:
	_clear_hydrate_target()
	_move_start_distance = 0.0
	_action_progress_ratio = 0.0


func _sync_movement_progress_target(target_distance: float) -> void:
	if _target_kitchen != _last_target_kitchen:
		_last_target_kitchen = _target_kitchen
		_move_start_distance = maxf(target_distance, refill_distance + 1.0)
		_path_cells.clear()


func _update_movement_progress(_target_distance: float) -> void:
	_action_progress_ratio = 0.0


func _get_water_bottle_item() -> FoodItemData:
	if _water_bottle_item != null:
		return _water_bottle_item
	if water_bottle_item_path.is_empty():
		return null
	if not ResourceLoader.exists(water_bottle_item_path):
		return null
	var resource := load(water_bottle_item_path)
	if resource != null and resource is FoodItemData:
		_water_bottle_item = resource as FoodItemData
	return _water_bottle_item


func _ensure_hydrate_target() -> bool:
	if _has_valid_hydrate_target():
		return true

	_set_hydrate_target(_find_nearest_kitchen_module())
	return _target_kitchen != null


func _has_valid_hydrate_target() -> bool:
	if _target_kitchen == null:
		return false
	if not is_instance_valid(_target_kitchen):
		return false
	if _furniture_root != null and _target_kitchen.get_parent() != _furniture_root:
		return false
	if not _is_kitchen_module(_target_kitchen):
		return false
	if _has_target_kitchen_layout_changed(_target_kitchen):
		return false
	if _is_valid_grid_position(_target_cell):
		if _is_target_cell_walkable(_target_cell, _get_actor_grid_footprint()):
			return true
		if not _is_target_cell_inside(_target_cell, _get_actor_grid_footprint()):
			return false
		return _get_kitchen_use_cell(_target_kitchen) == _target_cell
	return _is_close_enough_to_refill(_target_kitchen)


func _set_hydrate_target(kitchen: Node2D) -> void:
	var previous_kitchen: Node2D = null
	if _target_kitchen != null and is_instance_valid(_target_kitchen):
		previous_kitchen = _target_kitchen
	var previous_cell := _target_cell
	if kitchen == null:
		_clear_hydrate_target()
		return

	_target_kitchen = kitchen
	_target_kitchen_grid_position = _get_furniture_grid_position(_target_kitchen)
	_target_kitchen_grid_footprint = _get_furniture_footprint(_target_kitchen)
	_target_cell = _get_kitchen_use_cell(_target_kitchen)

	if previous_kitchen != _target_kitchen or previous_cell != _target_cell:
		_last_target_kitchen = null
		_move_start_distance = 0.0
		_path_cells.clear()


func _clear_hydrate_target() -> void:
	_target_kitchen = null
	_last_target_kitchen = null
	_target_cell = INVALID_GRID_POSITION
	_target_kitchen_grid_position = INVALID_GRID_POSITION
	_target_kitchen_grid_footprint = Vector2i.ZERO
	_path_cells.clear()


func _has_target_kitchen_layout_changed(kitchen: Node2D) -> bool:
	return (
		_get_furniture_grid_position(kitchen) != _target_kitchen_grid_position
		or _get_furniture_footprint(kitchen) != _target_kitchen_grid_footprint
	)


func _find_nearest_kitchen_module() -> Node2D:
	if _furniture_root == null or _body == null:
		return null

	var nearest: Node2D = null
	var nearest_score := INF
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var distance_map := _get_grid_distance_map(start_cell)
	var fallback_distance_map: Dictionary = {}
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_kitchen_module(furniture):
			continue
		var target_cell := _get_kitchen_use_cell_with_distance_map(furniture, distance_map)
		var score_distance_map := distance_map
		if not _is_valid_grid_position(target_cell):
			if fallback_distance_map.is_empty():
				fallback_distance_map = _get_grid_distance_map(start_cell, true)
			target_cell = _get_kitchen_use_cell_with_distance_map(furniture, fallback_distance_map, true)
			score_distance_map = fallback_distance_map
		if not _is_valid_grid_position(target_cell):
			if _is_close_enough_to_refill(furniture):
				return furniture
			continue
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var path_score := _get_grid_distance_score(score_distance_map, target_cell)
		if path_score < 0.0 and not _is_close_enough_to_refill(furniture):
			continue
		var distance_score := _body.global_position.distance_squared_to(target_position) / 1000000.0
		var score := maxf(path_score, 0.0) + distance_score
		if nearest == null or score < nearest_score:
			nearest = furniture
			nearest_score = score
	return nearest


func _is_kitchen_module(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_provide_water") and furniture.call("can_provide_water") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if kitchen_module_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if kitchen_module_ids.has(property_id):
			return true
	return false


func _get_kitchen_use_position(kitchen: Node2D) -> Vector2:
	var use_cell := _target_cell if kitchen == _target_kitchen else _get_kitchen_use_cell(kitchen)
	return _get_kitchen_use_position_from_cell(kitchen, use_cell)


func _get_kitchen_use_position_from_cell(kitchen: Node2D, use_cell: Vector2i) -> Vector2:
	if _is_valid_grid_position(use_cell) and _room_map != null:
		return _room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())
	if kitchen != null:
		return kitchen.global_position
	return Vector2.ZERO


func _is_close_enough_to_refill(kitchen: Node2D) -> bool:
	if _body == null or kitchen == null:
		return false
	var nearest_position: Vector2 = _get_nearest_point_on_furniture_area(kitchen, _body.global_position)
	return _body.global_position.distance_to(nearest_position) <= nearby_refill_distance


func _is_near_refill_target_cell(target_cell: Vector2i) -> bool:
	if _body == null or _room_map == null or not _is_valid_grid_position(target_cell):
		return false
	var current_cell := _get_current_actor_top_left_grid_position()
	if not _is_valid_grid_position(current_cell):
		return false
	var grid_delta := current_cell - target_cell
	return abs(grid_delta.x) <= 1 and abs(grid_delta.y) <= 1


func _get_nearest_point_on_furniture_area(furniture: Node2D, world_position: Vector2) -> Vector2:
	if furniture == null:
		return world_position
	if _room_map != null and furniture.has_meta("grid_position"):
		var furniture_cell: Vector2i = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
		if _is_valid_grid_position(furniture_cell):
			var furniture_rect: Rect2 = _room_map.get_grid_area_rect(furniture_cell, _get_furniture_footprint(furniture))
			return Vector2(
				clampf(world_position.x, furniture_rect.position.x, furniture_rect.end.x),
				clampf(world_position.y, furniture_rect.position.y, furniture_rect.end.y)
			)
	return furniture.global_position


func _get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null:
		return INVALID_GRID_POSITION
	if not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


func _get_kitchen_use_cell(kitchen: Node2D) -> Vector2i:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var use_cell := _get_kitchen_use_cell_with_distance_map(kitchen, _get_grid_distance_map(start_cell))
	if _is_valid_grid_position(use_cell):
		return use_cell
	return _get_kitchen_use_cell_with_distance_map(kitchen, _get_grid_distance_map(start_cell, true), true)


func _get_kitchen_use_cell_with_distance_map(kitchen: Node2D, distance_map: Dictionary, allow_occupied: bool = false) -> Vector2i:
	if kitchen == null or _room_map == null:
		return INVALID_GRID_POSITION
	if not kitchen.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var kitchen_cell: Vector2i = kitchen.get_meta("grid_position", INVALID_GRID_POSITION)
	if kitchen_cell == INVALID_GRID_POSITION:
		return INVALID_GRID_POSITION

	var kitchen_footprint := _get_furniture_footprint(kitchen)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(kitchen_cell, kitchen_footprint, actor_footprint)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF

	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint, allow_occupied):
			continue
		var path_score := _get_grid_distance_score(distance_map, candidate)
		if path_score < 0.0:
			continue
		var candidate_position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance_score := _body.global_position.distance_squared_to(candidate_position) / 1000000.0
		var score := path_score + distance_score
		if nearest_cell == INVALID_GRID_POSITION or score < nearest_score:
			nearest_cell = candidate
			nearest_score = score

	return nearest_cell


func _get_side_candidate_cells(furniture_cell: Vector2i, furniture_footprint: Vector2i, actor_footprint: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.get_side_candidate_cells(furniture_cell, furniture_footprint, actor_footprint)


func _get_grid_path_velocity_to_target(target_cell: Vector2i, target_distance: float) -> Vector2:
	if _body == null or _room_map == null:
		return Vector2.ZERO
	if not _is_valid_grid_position(target_cell):
		return Vector2.ZERO

	var start_cell := _get_current_or_nearest_walkable_top_left_cell(true, true)
	if not _is_valid_grid_position(start_cell):
		return Vector2.ZERO

	if start_cell == target_cell:
		_path_cells.clear()
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var to_target := target_position - _body.global_position
		if to_target.length() > grid_arrival_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
			_update_movement_progress(target_distance)
			return _facing_direction * walk_speed
		return Vector2.ZERO

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return Vector2.ZERO

	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_target_cell_inside(waypoint_cell, _get_actor_grid_footprint()):
			_path_cells.clear()
			return Vector2.ZERO

		var waypoint_position := _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrival_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_waypoint)
			_update_movement_progress(target_distance)
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _get_grid_path_score_to_target(target_cell: Vector2i) -> float:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	return _get_grid_distance_score(_get_grid_distance_map(start_cell), target_cell)


func _get_grid_path_score(start_cell: Vector2i, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(start_cell) or not _is_valid_grid_position(target_cell):
		return -1.0
	if start_cell == target_cell:
		return 0.0
	return _get_grid_distance_score(_get_grid_distance_map(start_cell), target_cell)


func _get_grid_distance_map(start_cell: Vector2i, allow_occupied: bool = false) -> Dictionary:
	var walkable_callable := Callable(self, "_is_target_cell_walkable")
	if allow_occupied:
		walkable_callable = Callable(self, "_is_target_cell_inside")
	return AICharacterGridMovementHelper.get_grid_distance_map(
		start_cell,
		_get_actor_grid_footprint(),
		walkable_callable,
		INVALID_GRID_POSITION
	)


func _get_grid_distance_score(distance_map: Dictionary, target_cell: Vector2i) -> float:
	return AICharacterGridMovementHelper.get_grid_distance_score(distance_map, target_cell, INVALID_GRID_POSITION)


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.find_grid_path_with_fallback(
		start_cell,
		target_cell,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_walkable"),
		Callable(self, "_is_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _get_current_or_nearest_walkable_top_left_cell(allow_snap: bool, allow_occupied: bool = false) -> Vector2i:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_target_cell_walkable(current_cell, _get_actor_grid_footprint()):
		return current_cell
	if allow_occupied and _is_target_cell_inside(current_cell, _get_actor_grid_footprint()):
		return current_cell

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if allow_snap and _is_valid_grid_position(nearest_cell):
		_body.global_position = _room_map.grid_to_world_area_center(nearest_cell, _get_actor_grid_footprint())
		_path_cells.clear()
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	if _room_map == null or _body == null:
		return INVALID_GRID_POSITION
	return AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
		_room_map,
		_body.global_position,
		_get_actor_grid_footprint(),
		INVALID_GRID_POSITION
	)


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	if _room_map == null:
		return INVALID_GRID_POSITION
	var nearest_cell := AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_walkable"),
		INVALID_GRID_POSITION
	)
	if _is_valid_grid_position(nearest_cell):
		return nearest_cell
	return AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i, allow_occupied: bool = false) -> bool:
	if not _is_target_cell_inside(cell, footprint):
		return false
	if allow_occupied:
		return true
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


func _is_target_cell_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	return _room_map.is_grid_area_inside(cell, footprint)


func _get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if furniture == null:
		return Vector2i(1, 1)
	if furniture.has_method("get_grid_footprint"):
		var method_footprint: Vector2i = furniture.call("get_grid_footprint")
		return Vector2i(maxi(method_footprint.x, 1), maxi(method_footprint.y, 1))
	if furniture.has_meta("grid_footprint"):
		var meta_footprint: Vector2i = furniture.get_meta("grid_footprint", Vector2i(1, 1))
		return Vector2i(maxi(meta_footprint.x, 1), maxi(meta_footprint.y, 1))
	return Vector2i(1, 1)


func _get_actor_grid_footprint() -> Vector2i:
	return AICharacterGridMovementHelper.get_safe_footprint(actor_grid_footprint)


func _tick_cooldown(delta: float) -> void:
	if _cooldown_timer <= 0.0:
		return
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)


func _grid_key(grid_position: Vector2i) -> String:
	return AICharacterGridMovementHelper.grid_key(grid_position)


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return AICharacterGridMovementHelper.is_valid_grid_position(grid_position, INVALID_GRID_POSITION)


func _resolve_refs() -> void:
	if _needs_module == null and not needs_module_path.is_empty():
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if _need_planner == null and not need_planner_path.is_empty():
		_need_planner = get_node_or_null(need_planner_path) as NeedDrivenAIPlanner
	if _inventory_module == null and not inventory_module_path.is_empty():
		_inventory_module = get_node_or_null(inventory_module_path) as RobinInventoryModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false
