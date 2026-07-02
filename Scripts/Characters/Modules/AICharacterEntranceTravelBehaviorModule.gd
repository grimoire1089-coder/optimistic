extends Node
class_name AICharacterEntranceTravelBehaviorModule

signal travel_completed(target_map_id: StringName)

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)

@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var map_travel_module_path: NodePath = NodePath("../../MainSceneMapTravelModule")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var walk_speed: float = 80.0
@export var arrive_distance: float = 14.0
@export var grid_arrive_distance: float = 6.0
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var use_time_seconds: float = 0.45

var _body: CharacterBody2D
var _room_map: RoomMapGridModule
var _map_travel_module: Node
var _furniture_placement_module: Node
var _target_entrance: Node2D
var _target_cell: Vector2i = INVALID_GRID_POSITION
var _target_entrance_grid_position: Vector2i = INVALID_GRID_POSITION
var _target_entrance_grid_footprint: Vector2i = Vector2i.ZERO
var _target_map_id: StringName = &""
var _active := false
var _using := false
var _use_timer := 0.0
var _facing_direction := Vector2.DOWN
var _path_cells: Array[Vector2i] = []


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func is_active() -> bool:
	return _active


func get_facing_direction() -> Vector2:
	return _facing_direction


func request_travel_to_entrance(entrance: Node2D, target_map_id: StringName) -> bool:
	_resolve_refs()
	if _active:
		return false
	if _body == null or entrance == null or target_map_id == &"":
		return false
	var entrance_map := _get_room_map_for_entrance(entrance)
	if entrance_map != null:
		_room_map = entrance_map
	if _room_map == null:
		return false
	var use_cell := _get_entrance_use_cell(entrance)
	if not _is_valid_grid_position(use_cell):
		return false
	_target_entrance = entrance
	_target_cell = use_cell
	_target_entrance_grid_position = _get_furniture_grid_position(entrance)
	_target_entrance_grid_footprint = _get_furniture_footprint(entrance)
	_target_map_id = target_map_id
	_active = true
	_using = false
	_use_timer = 0.0
	_path_cells.clear()
	return true


func _has_valid_target_entrance() -> bool:
	if _target_entrance == null:
		return false
	if not is_instance_valid(_target_entrance):
		return false
	if _get_furniture_grid_position(_target_entrance) != _target_entrance_grid_position:
		return false
	if _get_furniture_footprint(_target_entrance) != _target_entrance_grid_footprint:
		return false
	if not _is_valid_grid_position(_target_cell):
		return false
	return _is_target_cell_walkable(_target_cell, _get_actor_grid_footprint())


func _refresh_target_entrance_cell() -> bool:
	if _target_entrance == null or not is_instance_valid(_target_entrance):
		return false
	_target_entrance_grid_position = _get_furniture_grid_position(_target_entrance)
	_target_entrance_grid_footprint = _get_furniture_footprint(_target_entrance)
	_target_cell = _get_entrance_use_cell(_target_entrance)
	_path_cells.clear()
	return _is_valid_grid_position(_target_cell)


func cancel_travel() -> void:
	_reset()


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	if not _active:
		return Vector2.ZERO
	if _body == null or _room_map == null or _target_entrance == null or not is_instance_valid(_target_entrance):
		_reset()
		return Vector2.ZERO

	if _using:
		_tick_use(delta)
		return Vector2.ZERO

	if not _has_valid_target_entrance() and not _refresh_target_entrance_cell():
		_reset()
		return Vector2.ZERO

	var target_cell := _target_cell
	var use_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
	var to_target := use_position - _body.global_position
	if to_target.length() <= arrive_distance:
		_start_use()
		return Vector2.ZERO

	var grid_velocity := _get_grid_path_velocity_to_target(target_cell)
	if grid_velocity != Vector2.ZERO:
		return grid_velocity

	to_target = use_position - _body.global_position
	if to_target.length() <= arrive_distance:
		_start_use()
		return Vector2.ZERO

	_reset()
	return Vector2.ZERO


func _start_use() -> void:
	_using = true
	_use_timer = 0.0
	_path_cells.clear()
	_face_entrance()


func _tick_use(delta: float) -> void:
	_face_entrance()
	_use_timer += maxf(delta, 0.0)
	if _use_timer < maxf(use_time_seconds, 0.01):
		return
	var completed_target_map_id := _target_map_id
	_reset()
	_perform_map_travel(completed_target_map_id)
	travel_completed.emit(completed_target_map_id)


func _perform_map_travel(target_map_id: StringName) -> void:
	_resolve_refs()
	if _map_travel_module == null:
		return
	if _map_travel_module.has_method("travel_to_map"):
		_map_travel_module.call("travel_to_map", target_map_id)
		_place_body_near_active_map_entrance()


func _place_body_near_active_map_entrance() -> void:
	if _body == null or _map_travel_module == null:
		return
	if not _map_travel_module.has_method("get_active_map"):
		return
	var active_map: RoomMapGridModule = _map_travel_module.call("get_active_map") as RoomMapGridModule
	if active_map == null:
		return
	var entrance := _find_entrance_in_map(active_map)
	if entrance == null:
		return
	var use_cell := _get_entrance_spawn_cell(active_map, entrance)
	if not _is_valid_grid_position(use_cell):
		return
	_room_map = active_map
	_body.global_position = active_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())
	_face_node(entrance)


func _find_entrance_in_map(room_map: RoomMapGridModule) -> Node2D:
	if room_map == null:
		return null
	var furniture_root := room_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return null
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if furniture is EntranceFurniture:
			return furniture
		if furniture.has_meta("furniture_id") and StringName(furniture.get_meta("furniture_id", &"")) == &"entrance":
			return furniture
	return null


func _get_entrance_spawn_cell(room_map: RoomMapGridModule, entrance: Node2D) -> Vector2i:
	if room_map == null or entrance == null or not entrance.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var entrance_cell: Vector2i = entrance.get_meta("grid_position", INVALID_GRID_POSITION)
	if entrance_cell == INVALID_GRID_POSITION:
		return INVALID_GRID_POSITION
	var entrance_footprint := _get_furniture_footprint(entrance)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(entrance_cell, entrance_footprint, actor_footprint)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF

	for candidate in candidates:
		if not _is_spawn_cell_free(room_map, candidate, actor_footprint):
			continue
		var candidate_position := room_map.grid_to_world_area_center(candidate, actor_footprint)
		var score := entrance.global_position.distance_squared_to(candidate_position)
		if nearest_cell == INVALID_GRID_POSITION or score < nearest_score:
			nearest_cell = candidate
			nearest_score = score
	return nearest_cell


func _get_entrance_use_cell(entrance: Node2D) -> Vector2i:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	return _get_entrance_use_cell_with_distance_map(entrance, _get_grid_distance_map(start_cell))


func _get_entrance_use_cell_with_distance_map(entrance: Node2D, distance_map: Dictionary) -> Vector2i:
	if entrance == null or _room_map == null:
		return INVALID_GRID_POSITION
	if not entrance.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var entrance_cell: Vector2i = entrance.get_meta("grid_position", INVALID_GRID_POSITION)
	if entrance_cell == INVALID_GRID_POSITION:
		return INVALID_GRID_POSITION
	var entrance_footprint := _get_furniture_footprint(entrance)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(entrance_cell, entrance_footprint, actor_footprint)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF

	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint):
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
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var to_target := target_position - _body.global_position
		if to_target.length() > grid_arrive_distance:
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

		var waypoint_position := _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrive_distance:
			_facing_direction = to_waypoint.normalized()
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _get_grid_path_score(start_cell: Vector2i, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(start_cell) or not _is_valid_grid_position(target_cell):
		return -1.0
	if start_cell == target_cell:
		return 0.0
	return _get_grid_distance_score(_get_grid_distance_map(start_cell), target_cell)


func _get_grid_distance_map(start_cell: Vector2i) -> Dictionary:
	var distances: Dictionary = {}
	var footprint := _get_actor_grid_footprint()
	if not _is_valid_grid_position(start_cell):
		return distances
	if not _is_target_cell_walkable(start_cell, footprint):
		return distances

	var frontier: Array[Vector2i] = [start_cell]
	distances[_grid_key(start_cell)] = 0
	var read_index := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

	while read_index < frontier.size():
		var current := frontier[read_index]
		read_index += 1
		var current_distance := int(distances[_grid_key(current)])

		for step in steps:
			var next_cell := current + step
			var next_key := _grid_key(next_cell)
			if distances.has(next_key):
				continue
			if not _is_target_cell_walkable(next_cell, footprint):
				continue
			distances[next_key] = current_distance + 1
			frontier.append(next_cell)

	return distances


func _get_grid_distance_score(distance_map: Dictionary, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(target_cell):
		return -1.0
	var target_key := _grid_key(target_cell)
	if not distance_map.has(target_key):
		return -1.0
	return float(int(distance_map[target_key]))


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


func _is_spawn_cell_free(room_map: RoomMapGridModule, cell: Vector2i, footprint: Vector2i) -> bool:
	if room_map == null or not room_map.is_grid_area_inside(cell, footprint):
		return false
	var furniture_root := room_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return true
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null or not furniture.has_meta("grid_position"):
			continue
		var furniture_cell: Vector2i = furniture.get_meta("grid_position", Vector2i.ZERO)
		var furniture_footprint := _get_furniture_footprint(furniture)
		if _grid_areas_overlap(cell, footprint, furniture_cell, furniture_footprint):
			return false
	return true


func _grid_areas_overlap(a_cell: Vector2i, a_footprint: Vector2i, b_cell: Vector2i, b_footprint: Vector2i) -> bool:
	return (
		a_cell.x < b_cell.x + b_footprint.x
		and a_cell.x + a_footprint.x > b_cell.x
		and a_cell.y < b_cell.y + b_footprint.y
		and a_cell.y + a_footprint.y > b_cell.y
	)


func _get_room_map_for_entrance(entrance: Node2D) -> RoomMapGridModule:
	var node := entrance.get_parent()
	while node != null:
		if node is RoomMapGridModule:
			return node as RoomMapGridModule
		node = node.get_parent()
	return null


func _face_entrance() -> void:
	_face_node(_target_entrance)


func _face_node(target: Node2D) -> void:
	if _body == null or target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - _body.global_position
	if to_target.length_squared() > 0.001:
		_facing_direction = to_target.normalized()


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


func _get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null or not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


func _get_actor_grid_footprint() -> Vector2i:
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _reset() -> void:
	_target_entrance = null
	_target_cell = INVALID_GRID_POSITION
	_target_entrance_grid_position = INVALID_GRID_POSITION
	_target_entrance_grid_footprint = Vector2i.ZERO
	_target_map_id = &""
	_active = false
	_using = false
	_use_timer = 0.0
	_path_cells.clear()


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_GRID_POSITION


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _map_travel_module == null and not map_travel_module_path.is_empty():
		_map_travel_module = get_node_or_null(map_travel_module_path)
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
