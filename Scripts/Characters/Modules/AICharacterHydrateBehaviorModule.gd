extends Node
class_name AICharacterHydrateBehaviorModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const MOVEMENT_PROGRESS_PORTION := 0.35

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


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func is_active() -> bool:
	return _is_active


func is_action_progress_visible() -> bool:
	return _is_active or _is_drinking


func get_action_progress_ratio() -> float:
	return clampf(_action_progress_ratio, 0.0, 1.0)


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	_tick_cooldown(delta)
	_is_active = false

	if _body == null or _needs_module == null:
		_reset_hydrate_action()
		return Vector2.ZERO

	if _is_drinking:
		_is_active = true
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

	_target_kitchen = _find_nearest_kitchen_module()
	if _target_kitchen == null:
		_reset_hydrate_action()
		return Vector2.ZERO

	_is_active = true
	var target_position := _get_kitchen_use_position(_target_kitchen)
	var to_target := target_position - _body.global_position
	var target_distance := to_target.length()
	_sync_movement_progress_target(target_distance)

	if target_distance <= refill_distance:
		var created_food_data := _create_water_bottle_for_drinking()
		if created_food_data != null:
			_begin_drinking(created_food_data, MOVEMENT_PROGRESS_PORTION)
		else:
			_finish_hydrate_action()
		return Vector2.ZERO

	if target_distance > arrival_distance:
		_facing_direction = to_target.normalized()
		_update_movement_progress(target_distance)
		return _facing_direction * walk_speed

	var food_data := _create_water_bottle_for_drinking()
	if food_data != null:
		_begin_drinking(food_data, MOVEMENT_PROGRESS_PORTION)
	else:
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
	_begin_drinking(food_data, 0.0)
	return true


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
	_drink_food_data = food_data
	_is_drinking = true
	_is_active = true
	_drink_timer = 0.0
	_drink_sfx_played = false
	_drink_start_progress = clampf(start_progress, 0.0, 0.95)
	_action_progress_ratio = _drink_start_progress
	_facing_direction = Vector2.DOWN


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
	_target_kitchen = null
	_last_target_kitchen = null
	_move_start_distance = 0.0
	_cooldown_timer = maxf(refill_cooldown_seconds, 0.0)
	_action_progress_ratio = 0.0
	_is_active = false


func _reset_hydrate_action() -> void:
	_target_kitchen = null
	_last_target_kitchen = null
	_move_start_distance = 0.0
	_action_progress_ratio = 0.0


func _sync_movement_progress_target(target_distance: float) -> void:
	if _target_kitchen != _last_target_kitchen:
		_last_target_kitchen = _target_kitchen
		_move_start_distance = maxf(target_distance, refill_distance + 1.0)


func _update_movement_progress(target_distance: float) -> void:
	var move_span := maxf(_move_start_distance - refill_distance, 1.0)
	var remaining := maxf(target_distance - refill_distance, 0.0)
	var move_ratio := clampf(1.0 - (remaining / move_span), 0.0, 1.0)
	_action_progress_ratio = move_ratio * MOVEMENT_PROGRESS_PORTION


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


func _find_nearest_kitchen_module() -> Node2D:
	if _furniture_root == null or _body == null:
		return null

	var nearest: Node2D = null
	var nearest_distance := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_kitchen_module(furniture):
			continue
		var target_position := _get_kitchen_use_position(furniture)
		var distance := _body.global_position.distance_squared_to(target_position)
		if nearest == null or distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
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
	var side_position := _get_kitchen_side_use_position(kitchen)
	if side_position.x != INF and side_position.y != INF:
		return side_position
	if kitchen != null:
		return kitchen.global_position
	return Vector2.ZERO


func _get_kitchen_side_use_position(kitchen: Node2D) -> Vector2:
	if kitchen == null or _room_map == null:
		return Vector2(INF, INF)
	if not kitchen.has_meta("grid_position"):
		return Vector2(INF, INF)
	var kitchen_cell: Vector2i = kitchen.get_meta("grid_position", INVALID_GRID_POSITION)
	if kitchen_cell == INVALID_GRID_POSITION:
		return Vector2(INF, INF)
	var kitchen_footprint := _get_furniture_footprint(kitchen)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(kitchen_cell, kitchen_footprint, actor_footprint)
	var nearest_position := Vector2(INF, INF)
	var nearest_distance := INF
	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint):
			continue
		var candidate_position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance := _body.global_position.distance_squared_to(candidate_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = candidate_position
	return nearest_position


func _get_side_candidate_cells(furniture_cell: Vector2i, furniture_footprint: Vector2i, actor_footprint: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var min_y := furniture_cell.y - actor_footprint.y + 1
	var max_y := furniture_cell.y + furniture_footprint.y - 1
	for y in range(min_y, max_y + 1):
		candidates.append(Vector2i(furniture_cell.x - actor_footprint.x, y))
		candidates.append(Vector2i(furniture_cell.x + furniture_footprint.x, y))

	var min_x := furniture_cell.x - actor_footprint.x + 1
	var max_x := furniture_cell.x + furniture_footprint.x - 1
	for x in range(min_x, max_x + 1):
		candidates.append(Vector2i(x, furniture_cell.y - actor_footprint.y))
		candidates.append(Vector2i(x, furniture_cell.y + furniture_footprint.y))
	return candidates


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	if not _room_map.is_grid_area_inside(cell, footprint):
		return false
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


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
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _tick_cooldown(delta: float) -> void:
	if _cooldown_timer <= 0.0:
		return
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)


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
