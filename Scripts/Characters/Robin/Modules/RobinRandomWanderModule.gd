extends Node
class_name RobinRandomWanderModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)

@export var walk_speed: float = 80.0
@export var screen_margin: float = 96.0
@export var side_ui_margin: float = 280.0
@export var movement_area_provider_path: NodePath
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var idle_chance: float = 0.65
@export var idle_time_range: Vector2 = Vector2(2.5, 5.5)
@export var walk_time_range: Vector2 = Vector2(1.0, 2.2)
@export var use_grid_path_movement: bool = true
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var grid_arrival_distance: float = 6.0

# 枠線からキャラクター画像がはみ出さないよう、原点の移動範囲を内側へ縮める量です。
# 物理コリジョンではなく、見た目サイズ用の余白です。
@export var visual_half_extents: Vector2 = Vector2(48.0, 76.0)
@export var keep_visual_inside_frame: bool = true

var _body: Node2D
var _movement_area_provider: Node
var _furniture_placement_module: Node
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _is_idle: bool = false
var _direction: Vector2 = Vector2.DOWN
var _walk_directions: Array[Vector2] = []
var _path_cells: Array[Vector2i] = []
var _walkable_cells_cache: Array[Vector2i] = []
var _walkable_cells_cache_version := -1
var _walkable_cells_cache_room_map: RoomMapGridModule
var _walkable_cells_cache_placement: Node
var _walkable_cells_cache_footprint := Vector2i.ZERO


func setup(body: Node2D) -> void:
	_body = body
	_resolve_movement_area_provider()
	_resolve_furniture_placement_module()
	_rng.randomize()
	_setup_walk_directions()
	_pick_next_action()


func set_movement_area_provider_path(next_provider_path: NodePath) -> void:
	if movement_area_provider_path == next_provider_path:
		_resolve_movement_area_provider()
		return
	movement_area_provider_path = next_provider_path
	_movement_area_provider = null
	_invalidate_walkable_cells_cache()
	_resolve_movement_area_provider()
	_path_cells.clear()
	_pick_next_action()
	clamp_body_to_movement_area()


func get_velocity(delta: float) -> Vector2:
	if _body == null:
		return Vector2.ZERO

	_keep_inside_movement_area()

	if _is_idle:
		_timer -= delta
		if _timer <= 0.0:
			_pick_next_action()
		return Vector2.ZERO

	if _uses_grid_path_movement():
		return _get_grid_path_velocity()

	_timer -= delta
	if _timer <= 0.0:
		_pick_next_action()

	return _direction * walk_speed


func get_facing_direction() -> Vector2:
	return _direction


func get_movement_center() -> Vector2:
	if _body == null:
		return Vector2.ZERO

	var movement_area := get_movement_area()
	var fallback_center := movement_area.position + movement_area.size * 0.5
	if not _uses_grid_path_movement():
		return fallback_center

	var nearest_top_left := _get_nearest_walkable_top_left_to_world_position(fallback_center)
	if not _is_valid_grid_position(nearest_top_left):
		return fallback_center
	return _get_actor_grid_area_center(nearest_top_left)


func get_visual_movement_area() -> Rect2:
	var provider_area := _get_provider_visual_map_rect()
	if provider_area.size.x > 0.0 and provider_area.size.y > 0.0:
		return provider_area

	if _body == null:
		return Rect2()

	var rect := _body.get_viewport().get_visible_rect()
	var min_pos := rect.position + Vector2(side_ui_margin, screen_margin)
	var max_pos := rect.end - Vector2(side_ui_margin, screen_margin)
	var center := rect.position + rect.size * 0.5

	if min_pos.x > max_pos.x:
		min_pos.x = center.x
		max_pos.x = center.x

	if min_pos.y > max_pos.y:
		min_pos.y = center.y
		max_pos.y = center.y

	var available_size := max_pos - min_pos
	available_size.x = maxf(available_size.x, 0.0)
	available_size.y = maxf(available_size.y, 0.0)

	var square_size := minf(available_size.x, available_size.y)
	var square_area_size := Vector2(square_size, square_size)
	var square_area_position := min_pos + (available_size - square_area_size) * 0.5
	return Rect2(square_area_position, square_area_size)


func get_movement_area() -> Rect2:
	var visual_area := get_visual_movement_area()
	if not keep_visual_inside_frame:
		return visual_area

	return _get_inset_area_for_actor_origin(visual_area)


func clamp_body_to_movement_area() -> bool:
	if _body == null:
		return false

	if _uses_grid_path_movement():
		return _clamp_body_to_grid_footprint_area()

	var movement_area := get_movement_area()
	var area_end := movement_area.end
	var current_position := _body.global_position
	var clamped_position := Vector2(
		clampf(current_position.x, movement_area.position.x, area_end.x),
		clampf(current_position.y, movement_area.position.y, area_end.y)
	)

	if current_position.distance_squared_to(clamped_position) <= 0.001:
		return false

	_body.global_position = clamped_position
	return true


func _get_inset_area_for_actor_origin(area: Rect2) -> Rect2:
	var inset_x := minf(visual_half_extents.x, area.size.x * 0.5)
	var inset_y := minf(visual_half_extents.y, area.size.y * 0.5)
	var inset_position := area.position + Vector2(inset_x, inset_y)
	var inset_size := area.size - Vector2(inset_x * 2.0, inset_y * 2.0)
	inset_size.x = maxf(inset_size.x, 0.0)
	inset_size.y = maxf(inset_size.y, 0.0)
	return Rect2(inset_position, inset_size)


func _setup_walk_directions() -> void:
	if not _walk_directions.is_empty():
		return

	_walk_directions = [
		Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(),
		Vector2.RIGHT,
		Vector2(1.0, -1.0).normalized(),
		Vector2.UP,
		Vector2(-1.0, -1.0).normalized(),
		Vector2.LEFT,
		Vector2(-1.0, 1.0).normalized(),
	]


func _pick_next_action() -> void:
	_setup_walk_directions()
	_path_cells.clear()
	_is_idle = _rng.randf() < idle_chance

	if _is_idle:
		_start_idle()
		return

	if _uses_grid_path_movement():
		if _pick_next_grid_path():
			return
		_start_idle()
		return

	_timer = _rng.randf_range(walk_time_range.x, walk_time_range.y)
	_direction = _walk_directions[_rng.randi_range(0, _walk_directions.size() - 1)]


func _start_idle() -> void:
	_is_idle = true
	_timer = _rng.randf_range(idle_time_range.x, idle_time_range.y)


func _get_grid_path_velocity() -> Vector2:
	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_actor_grid_area_walkable(waypoint_cell):
			_pick_next_action()
			return Vector2.ZERO

		var waypoint_position := _get_actor_grid_area_center(waypoint_cell)
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrival_distance:
			_direction = to_waypoint.normalized()
			return _direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	_start_idle()
	return Vector2.ZERO


func _pick_next_grid_path() -> bool:
	var start_cell := _get_current_actor_top_left_grid_position()
	if not _is_actor_grid_area_walkable(start_cell):
		start_cell = _get_nearest_walkable_top_left_to_world_position(_body.global_position)
		if not _is_valid_grid_position(start_cell):
			return false
		_body.global_position = _get_actor_grid_area_center(start_cell)

	var target_cell := _pick_random_walkable_top_left_excluding(start_cell)
	if not _is_valid_grid_position(target_cell) or target_cell == start_cell:
		return false

	_path_cells = _find_grid_path(start_cell, target_cell)
	return not _path_cells.is_empty()


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if start_cell == target_cell:
		return path
	if not _is_actor_grid_area_walkable(start_cell) or not _is_actor_grid_area_walkable(target_cell):
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
			if not _is_actor_grid_area_walkable(next_cell):
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


func _pick_random_walkable_top_left_excluding(excluded_cell: Vector2i) -> Vector2i:
	var candidates := _get_all_walkable_top_left_cells()
	if candidates.is_empty():
		return INVALID_GRID_POSITION
	if candidates.size() == 1:
		return candidates[0]

	for _i in range(16):
		var candidate := candidates[_rng.randi_range(0, candidates.size() - 1)]
		if candidate != excluded_cell:
			return candidate

	for candidate in candidates:
		if candidate != excluded_cell:
			return candidate

	return INVALID_GRID_POSITION


func _get_all_walkable_top_left_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var room_map := _get_room_map()
	if room_map == null:
		return cells

	var grid_size := room_map.get_grid_size()
	var footprint := _get_safe_actor_grid_footprint()
	var furniture_placement := _get_furniture_placement_module()
	var layout_version := _get_walkable_layout_version(furniture_placement)
	if _walkable_cells_cache_room_map == room_map:
		if _walkable_cells_cache_placement == furniture_placement:
			if _walkable_cells_cache_footprint == footprint and _walkable_cells_cache_version == layout_version:
				return _walkable_cells_cache

	var max_x := grid_size.x - footprint.x
	var max_y := grid_size.y - footprint.y
	if max_x < 0 or max_y < 0:
		return cells

	for y in range(max_y + 1):
		for x in range(max_x + 1):
			var cell := Vector2i(x, y)
			if _is_actor_grid_area_walkable(cell):
				cells.append(cell)
	_walkable_cells_cache = cells
	_walkable_cells_cache_room_map = room_map
	_walkable_cells_cache_placement = furniture_placement
	_walkable_cells_cache_footprint = footprint
	_walkable_cells_cache_version = layout_version
	return cells


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_distance := INF
	for cell in _get_all_walkable_top_left_cells():
		var center := _get_actor_grid_area_center(cell)
		var distance := world_position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_cell = cell
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	var room_map := _get_room_map()
	if room_map == null or _body == null:
		return INVALID_GRID_POSITION
	var footprint := _get_safe_actor_grid_footprint()
	var center_cell := room_map.world_to_grid(_body.global_position)
	return center_cell - Vector2i(floori(float(footprint.x) * 0.5), floori(float(footprint.y) * 0.5))


func _get_actor_grid_area_center(top_left_cell: Vector2i) -> Vector2:
	var room_map := _get_room_map()
	if room_map == null:
		return Vector2.ZERO
	return room_map.grid_to_world_area_center(top_left_cell, _get_safe_actor_grid_footprint())


func _is_actor_grid_area_walkable(top_left_cell: Vector2i) -> bool:
	if not _is_valid_grid_position(top_left_cell):
		return false
	var room_map := _get_room_map()
	if room_map == null:
		return false
	var footprint := _get_safe_actor_grid_footprint()
	if not room_map.is_grid_area_inside(top_left_cell, footprint):
		return false

	var furniture_placement := _get_furniture_placement_module()
	if furniture_placement != null and furniture_placement.has_method("can_place_at"):
		return furniture_placement.call("can_place_at", top_left_cell, footprint) == true

	return true


func _clamp_body_to_grid_footprint_area() -> bool:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_actor_grid_area_walkable(current_cell):
		return false

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if not _is_valid_grid_position(nearest_cell):
		return false

	var clamped_position := _get_actor_grid_area_center(nearest_cell)
	if _body.global_position.distance_squared_to(clamped_position) <= 0.001:
		return false

	_body.global_position = clamped_position
	_path_cells.clear()
	return true


func _keep_inside_movement_area() -> void:
	if _uses_grid_path_movement():
		return

	var movement_area := get_movement_area()
	var min_pos := movement_area.position
	var max_pos := movement_area.end
	var position := _body.global_position
	var target_direction := Vector2.ZERO

	if position.x < min_pos.x:
		target_direction.x = 1.0
	elif position.x > max_pos.x:
		target_direction.x = -1.0

	if position.y < min_pos.y:
		target_direction.y = 1.0
	elif position.y > max_pos.y:
		target_direction.y = -1.0

	if target_direction != Vector2.ZERO:
		_direction = target_direction.normalized()
		_is_idle = false
		_timer = max(_timer, 0.35)


func _uses_grid_path_movement() -> bool:
	return use_grid_path_movement and _get_room_map() != null and _get_safe_actor_grid_footprint().x > 0 and _get_safe_actor_grid_footprint().y > 0


func _get_safe_actor_grid_footprint() -> Vector2i:
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _get_room_map() -> RoomMapGridModule:
	_resolve_movement_area_provider()
	return _movement_area_provider as RoomMapGridModule


func _get_furniture_placement_module() -> Node:
	_resolve_furniture_placement_module()
	return _furniture_placement_module


func _get_walkable_layout_version(furniture_placement: Node) -> int:
	if furniture_placement != null and furniture_placement.has_method("get_layout_version"):
		return int(furniture_placement.call("get_layout_version"))
	return 0


func _invalidate_walkable_cells_cache() -> void:
	_walkable_cells_cache.clear()
	_walkable_cells_cache_version = -1
	_walkable_cells_cache_room_map = null
	_walkable_cells_cache_placement = null
	_walkable_cells_cache_footprint = Vector2i.ZERO


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_GRID_POSITION


func _get_provider_visual_map_rect() -> Rect2:
	_resolve_movement_area_provider()
	if _movement_area_provider == null:
		return Rect2()
	if not _movement_area_provider.has_method("get_visual_map_rect"):
		return Rect2()
	var provider_area: Rect2 = _movement_area_provider.call("get_visual_map_rect")
	return provider_area


func _resolve_movement_area_provider() -> void:
	if _movement_area_provider != null:
		return
	if movement_area_provider_path.is_empty():
		return

	_movement_area_provider = get_node_or_null(movement_area_provider_path)
	if _movement_area_provider != null:
		return

	if _body != null:
		_movement_area_provider = _body.get_node_or_null(movement_area_provider_path)


func _resolve_furniture_placement_module() -> void:
	if _furniture_placement_module != null:
		return
	if furniture_placement_module_path.is_empty():
		return

	_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
	if _furniture_placement_module != null:
		return

	if _body != null:
		_furniture_placement_module = _body.get_node_or_null(furniture_placement_module_path)
