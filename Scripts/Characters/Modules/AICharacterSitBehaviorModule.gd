extends Node
class_name AICharacterSitBehaviorModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const BUILD_LOCK_META := &"build_locked_by_sleep"
const BUILD_LOCK_REASON_META := &"build_lock_reason"

@export var need_planner_path: NodePath = NodePath("../AICharacterNeedsBundle/NeedDrivenAIPlanner")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var stool_ids: Array[StringName] = [&"stool"]
@export var walk_speed: float = 80.0
@export var arrive_distance: float = 12.0
@export var grid_arrival_distance: float = 6.0
@export var sit_chance: float = 1.0
@export var sit_duration_range: Vector2 = Vector2(45.0, 120.0)
@export var retry_cooldown_range: Vector2 = Vector2(20.0, 45.0)
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var snap_to_stool_when_sitting: bool = true

var _body: CharacterBody2D
var _need_planner: NeedDrivenAIPlanner
var _furniture_root: Node
var _furniture_placement_module: Node
var _room_map: RoomMapGridModule
var _target_stool: Node2D
var _sitting_stool: Node2D
var _target_cell: Vector2i = INVALID_GRID_POSITION
var _path_cells: Array[Vector2i] = []
var _active := false
var _sitting := false
var _sit_timer := 0.0
var _retry_cooldown := 0.0
var _facing_direction := Vector2.DOWN
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()
	_rng.randomize()


func is_active() -> bool:
	return _active


func is_sitting() -> bool:
	return _sitting


func cancel_sitting() -> void:
	_reset()


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_debug_path_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _sitting:
		return result
	for cell in _path_cells:
		result.append(cell)
	return result


func get_debug_target_cell() -> Vector2i:
	if _sitting:
		return INVALID_GRID_POSITION
	return _target_cell


func get_debug_next_cell() -> Vector2i:
	if _sitting:
		return INVALID_GRID_POSITION
	if _path_cells.is_empty():
		return INVALID_GRID_POSITION
	return _path_cells[0]


func get_debug_actor_footprint() -> Vector2i:
	return _get_actor_grid_footprint()


func get_debug_movement_summary() -> String:
	if _sitting:
		return "sitting=true stool_cell=%s lower_body_footprint=%s" % [
			str(_get_furniture_grid_position(_sitting_stool)),
			str(Vector2i(2, 2)),
		]
	return "target_cell=%s next_cell=%s path=%d footprint=%s sitting=%s" % [
		str(get_debug_target_cell()),
		str(get_debug_next_cell()),
		_path_cells.size(),
		str(get_debug_actor_footprint()),
		str(_sitting),
	]


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	_tick_retry_cooldown(delta)

	if _body == null:
		_reset()
		return Vector2.ZERO
	if not _should_sit_now():
		_reset()
		return Vector2.ZERO

	if _sitting:
		_active = true
		_update_sitting(delta)
		return Vector2.ZERO

	if _retry_cooldown > 0.0:
		_active = false
		return Vector2.ZERO

	if not _ensure_target_stool():
		_active = false
		_start_retry_cooldown()
		return Vector2.ZERO

	_active = true
	var target_position := _get_stool_use_position(_target_cell)
	var to_target := target_position - _body.global_position
	if to_target.length() <= arrive_distance:
		_start_sitting()
		return Vector2.ZERO

	var path_velocity := _get_grid_path_velocity_to_target(_target_cell)
	if path_velocity != Vector2.ZERO:
		return path_velocity

	to_target = target_position - _body.global_position
	if to_target.length() <= arrive_distance:
		_start_sitting()
		return Vector2.ZERO

	_clear_target()
	_active = false
	_start_retry_cooldown()
	return Vector2.ZERO


func _should_sit_now() -> bool:
	if _need_planner == null:
		return true
	return _need_planner.get_next_action_id() == CharacterNeedActionIds.IDLE


func _ensure_target_stool() -> bool:
	if _has_valid_target_stool():
		return true
	if _rng.randf() > clampf(sit_chance, 0.0, 1.0):
		_start_retry_cooldown()
		return false
	_set_target_stool(_find_nearest_stool())
	return _target_stool != null and _is_valid_grid_position(_target_cell)


func _has_valid_target_stool() -> bool:
	if _target_stool == null:
		return false
	if not is_instance_valid(_target_stool):
		return false
	if _furniture_root != null and _target_stool.get_parent() != _furniture_root:
		return false
	if not _is_stool(_target_stool):
		return false
	if not _is_valid_grid_position(_target_cell):
		return false
	return _is_target_cell_walkable(_target_cell, _get_actor_grid_footprint())


func _set_target_stool(stool: Node2D) -> void:
	var previous_stool: Node2D = null
	if _target_stool != null and is_instance_valid(_target_stool):
		previous_stool = _target_stool
	var previous_cell := _target_cell
	if stool == null:
		_clear_target()
		return

	_target_stool = stool
	_target_cell = _get_stool_use_cell(_target_stool)
	if previous_stool != _target_stool or previous_cell != _target_cell:
		_path_cells.clear()


func _clear_target() -> void:
	_target_stool = null
	_target_cell = INVALID_GRID_POSITION
	_path_cells.clear()


func _start_sitting() -> void:
	_active = true
	_sitting = true
	_sit_timer = _rng.randf_range(maxf(sit_duration_range.x, 0.1), maxf(sit_duration_range.y, sit_duration_range.x + 0.1))
	_path_cells.clear()
	_face_stool()
	_set_sitting_stool(_target_stool)
	if snap_to_stool_when_sitting and _target_stool != null and is_instance_valid(_target_stool):
		_body.global_position = _get_stool_sit_position(_target_stool)


func _update_sitting(delta: float) -> void:
	_face_stool()
	_sit_timer -= maxf(delta, 0.0)
	if _sit_timer <= 0.0:
		_reset()
		_start_retry_cooldown()


func _reset() -> void:
	_clear_sitting_stool_lock()
	_active = false
	_sitting = false
	_sit_timer = 0.0
	_clear_target()


func _set_sitting_stool(stool: Node2D) -> void:
	if _sitting_stool == stool:
		return
	_clear_sitting_stool_lock()
	_sitting_stool = stool
	if _sitting_stool == null:
		return
	_sitting_stool.set_meta(BUILD_LOCK_META, true)
	_sitting_stool.set_meta(BUILD_LOCK_REASON_META, "Sitting")


func _clear_sitting_stool_lock() -> void:
	if _sitting_stool == null:
		return
	if is_instance_valid(_sitting_stool):
		if _sitting_stool.has_meta(BUILD_LOCK_META):
			_sitting_stool.remove_meta(BUILD_LOCK_META)
		if _sitting_stool.has_meta(BUILD_LOCK_REASON_META):
			_sitting_stool.remove_meta(BUILD_LOCK_REASON_META)
	_sitting_stool = null


func _start_retry_cooldown() -> void:
	var min_seconds := maxf(retry_cooldown_range.x, 0.1)
	var max_seconds := maxf(retry_cooldown_range.y, min_seconds)
	_retry_cooldown = _rng.randf_range(min_seconds, max_seconds)


func _tick_retry_cooldown(delta: float) -> void:
	if _retry_cooldown <= 0.0:
		return
	_retry_cooldown = maxf(_retry_cooldown - maxf(delta, 0.0), 0.0)


func _find_nearest_stool() -> Node2D:
	if _furniture_root == null or _body == null:
		return null

	var nearest: Node2D = null
	var nearest_score := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_stool(furniture):
			continue
		var use_cell := _get_stool_use_cell(furniture)
		if not _is_valid_grid_position(use_cell):
			continue
		var use_position := _get_stool_use_position(use_cell)
		var path_score := _get_grid_path_score_to_target(use_cell)
		if path_score < 0.0:
			continue
		var distance_score := _body.global_position.distance_squared_to(use_position) / 1000000.0
		var score := path_score + distance_score
		if nearest == null or score < nearest_score:
			nearest = furniture
			nearest_score = score
	return nearest


func _is_stool(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_be_sat_on") and furniture.call("can_be_sat_on") == true:
		return true
	if furniture.has_method("is_stool") and furniture.call("is_stool") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if stool_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if stool_ids.has(property_id):
			return true
	return false


func _get_stool_use_cell(stool: Node2D) -> Vector2i:
	if stool == null or _room_map == null:
		return INVALID_GRID_POSITION
	var stool_cell := _get_furniture_grid_position(stool)
	if not _is_valid_grid_position(stool_cell):
		return INVALID_GRID_POSITION

	var stool_footprint := _get_furniture_footprint(stool)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(stool_cell, stool_footprint, actor_footprint)
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF

	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint):
			continue
		var path_score := _get_grid_path_score(start_cell, candidate)
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


func _get_grid_path_velocity_to_target(target_cell: Vector2i) -> Vector2:
	if _body == null or _room_map == null:
		return Vector2.ZERO
	if not _is_valid_grid_position(target_cell):
		return Vector2.ZERO

	var start_cell := _get_current_or_nearest_walkable_top_left_cell(true)
	if not _is_valid_grid_position(start_cell):
		return Vector2.ZERO

	if start_cell == target_cell:
		_path_cells.clear()
		var target_position := _get_stool_use_position(target_cell)
		var to_target := target_position - _body.global_position
		if to_target.length() > grid_arrival_distance:
			_facing_direction = to_target.normalized()
			return _facing_direction * walk_speed
		return Vector2.ZERO

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return Vector2.ZERO

	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_target_cell_walkable(waypoint_cell, _get_actor_grid_footprint()):
			_path_cells.clear()
			return Vector2.ZERO

		var waypoint_position := _get_stool_use_position(waypoint_cell)
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrival_distance:
			_facing_direction = to_waypoint.normalized()
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _get_grid_path_score_to_target(target_cell: Vector2i) -> float:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	return _get_grid_path_score(start_cell, target_cell)


func _get_grid_path_score(start_cell: Vector2i, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(start_cell) or not _is_valid_grid_position(target_cell):
		return -1.0
	if start_cell == target_cell:
		return 0.0
	var path := _find_grid_path(start_cell, target_cell)
	if path.is_empty():
		return -1.0
	return float(path.size())


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var footprint := _get_actor_grid_footprint()
	if start_cell == target_cell:
		return path
	if not _is_target_cell_walkable(start_cell, footprint) or not _is_target_cell_walkable(target_cell, footprint):
		return path

	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	came_from[_grid_key(start_cell)] = INVALID_GRID_POSITION
	var read_index := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

	while read_index < frontier.size():
		var current := frontier[read_index]
		read_index += 1
		if current == target_cell:
			break
		for step in steps:
			var next_cell := current + step
			var next_key := _grid_key(next_cell)
			if came_from.has(next_key):
				continue
			if not _is_target_cell_walkable(next_cell, footprint):
				continue
			came_from[next_key] = current
			frontier.append(next_cell)

	var target_key := _grid_key(target_cell)
	if not came_from.has(target_key):
		return path

	var trace_cell := target_cell
	while trace_cell != start_cell:
		path.insert(0, trace_cell)
		trace_cell = came_from[_grid_key(trace_cell)] as Vector2i
	return path


func _get_current_or_nearest_walkable_top_left_cell(allow_snap: bool) -> Vector2i:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_target_cell_walkable(current_cell, _get_actor_grid_footprint()):
		return current_cell

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if allow_snap and _is_valid_grid_position(nearest_cell):
		_body.global_position = _room_map.grid_to_world_area_center(nearest_cell, _get_actor_grid_footprint())
		_path_cells.clear()
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	if _room_map == null or _body == null:
		return INVALID_GRID_POSITION
	var footprint := _get_actor_grid_footprint()
	var center_cell := _room_map.world_to_grid(_body.global_position)
	return center_cell - Vector2i(floori(float(footprint.x) * 0.5), floori(float(footprint.y) * 0.5))


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_distance := INF
	if _room_map == null:
		return nearest_cell

	var grid_size := _room_map.get_grid_size()
	var footprint := _get_actor_grid_footprint()
	var max_x := grid_size.x - footprint.x
	var max_y := grid_size.y - footprint.y
	if max_x < 0 or max_y < 0:
		return nearest_cell

	for y in range(max_y + 1):
		for x in range(max_x + 1):
			var cell := Vector2i(x, y)
			if not _is_target_cell_walkable(cell, footprint):
				continue
			var center := _room_map.grid_to_world_area_center(cell, footprint)
			var distance := world_position.distance_squared_to(center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
	return nearest_cell


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	if not _room_map.is_grid_area_inside(cell, footprint):
		return false
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


func _get_stool_use_position(use_cell: Vector2i) -> Vector2:
	if _room_map == null or not _is_valid_grid_position(use_cell):
		return _body.global_position if _body != null else Vector2.ZERO
	return _room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())


func _get_stool_sit_position(stool: Node2D) -> Vector2:
	if stool == null:
		return _body.global_position if _body != null else Vector2.ZERO
	if _room_map != null:
		var stool_cell := _get_furniture_grid_position(stool)
		if _is_valid_grid_position(stool_cell):
			var stool_footprint := _get_furniture_footprint(stool)
			var actor_footprint := _get_actor_grid_footprint()
			var actor_top_left := Vector2i(
				stool_cell.x + floori(float(stool_footprint.x - actor_footprint.x) * 0.5),
				stool_cell.y + stool_footprint.y - actor_footprint.y
			)
			return _room_map.grid_to_world_area_center(actor_top_left, actor_footprint)
	if stool.has_method("get_sit_target_global_position"):
		var target_position: Vector2 = stool.call("get_sit_target_global_position")
		return target_position
	return stool.global_position


func _face_stool() -> void:
	if _target_stool == null or _body == null or not is_instance_valid(_target_stool):
		_facing_direction = Vector2.DOWN
		return
	var to_stool := _target_stool.global_position - _body.global_position
	if to_stool.length_squared() > 0.001:
		_facing_direction = to_stool.normalized()
	else:
		_facing_direction = Vector2.DOWN


func _get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null or not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


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


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_GRID_POSITION


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as CharacterBody2D
	if _need_planner == null and not need_planner_path.is_empty():
		_need_planner = get_node_or_null(need_planner_path) as NeedDrivenAIPlanner
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
