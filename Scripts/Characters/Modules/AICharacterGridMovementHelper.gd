extends RefCounted
class_name AICharacterGridMovementHelper

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)


static func get_axis_aligned_direction(to_target: Vector2, fallback: Vector2 = Vector2.DOWN) -> Vector2:
	if absf(to_target.x) >= absf(to_target.y):
		if not is_zero_approx(to_target.x):
			return Vector2.RIGHT if to_target.x > 0.0 else Vector2.LEFT
	if not is_zero_approx(to_target.y):
		return Vector2.DOWN if to_target.y > 0.0 else Vector2.UP
	if not is_zero_approx(to_target.x):
		return Vector2.RIGHT if to_target.x > 0.0 else Vector2.LEFT
	return fallback


static func get_axis_aligned_step_target(current_position: Vector2, target_position: Vector2) -> Vector2:
	var to_target := target_position - current_position
	var direction := get_axis_aligned_direction(to_target)
	if not is_zero_approx(direction.x):
		return Vector2(target_position.x, current_position.y)
	if not is_zero_approx(direction.y):
		return Vector2(current_position.x, target_position.y)
	return target_position


static func grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


static func is_valid_grid_position(grid_position: Vector2i, invalid_grid_position: Vector2i = INVALID_GRID_POSITION) -> bool:
	return grid_position != invalid_grid_position


static func get_safe_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))


static func get_current_actor_top_left_grid_position(
	room_map: RoomMapGridModule,
	world_position: Vector2,
	footprint: Vector2i,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Vector2i:
	if room_map == null:
		return invalid_grid_position
	var safe_footprint := get_safe_footprint(footprint)
	var cell_size := room_map.get_cell_size()
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return invalid_grid_position
	var local_position := world_position - room_map.get_grid_origin()
	return Vector2i(
		roundi(local_position.x / cell_size.x - float(safe_footprint.x) * 0.5),
		roundi(local_position.y / cell_size.y - float(safe_footprint.y) * 0.5)
	)


static func get_all_walkable_top_left_cells(
	room_map: RoomMapGridModule,
	footprint: Vector2i,
	is_walkable: Callable
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if room_map == null:
		return cells
	if not is_walkable.is_valid():
		return cells

	var safe_footprint := get_safe_footprint(footprint)
	var grid_size := room_map.get_grid_size()
	var max_x := grid_size.x - safe_footprint.x
	var max_y := grid_size.y - safe_footprint.y
	if max_x < 0 or max_y < 0:
		return cells

	for y in range(max_y + 1):
		for x in range(max_x + 1):
			var cell := Vector2i(x, y)
			if bool(is_walkable.call(cell, safe_footprint)):
				cells.append(cell)
	return cells


static func get_nearest_walkable_top_left_to_world_position(
	room_map: RoomMapGridModule,
	world_position: Vector2,
	footprint: Vector2i,
	is_walkable: Callable,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Vector2i:
	if room_map == null:
		return invalid_grid_position
	var safe_footprint := get_safe_footprint(footprint)
	return get_nearest_top_left_cell_from_cells(
		room_map,
		world_position,
		safe_footprint,
		get_all_walkable_top_left_cells(room_map, safe_footprint, is_walkable),
		invalid_grid_position
	)


static func get_nearest_top_left_cell_from_cells(
	room_map: RoomMapGridModule,
	world_position: Vector2,
	footprint: Vector2i,
	cells: Array[Vector2i],
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Vector2i:
	if room_map == null:
		return invalid_grid_position
	var nearest_cell := invalid_grid_position
	var nearest_distance := INF
	var safe_footprint := get_safe_footprint(footprint)
	for cell in cells:
		var center := room_map.grid_to_world_area_center(cell, safe_footprint)
		var distance := world_position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_cell = cell
	return nearest_cell


static func get_grid_distance_map(
	start_cell: Vector2i,
	footprint: Vector2i,
	is_walkable: Callable,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Dictionary:
	var distances: Dictionary = {}
	if not is_valid_grid_position(start_cell, invalid_grid_position):
		return distances
	if not is_walkable.is_valid():
		return distances

	var safe_footprint := get_safe_footprint(footprint)
	if not bool(is_walkable.call(start_cell, safe_footprint)):
		return distances

	var frontier: Array[Vector2i] = [start_cell]
	distances[grid_key(start_cell)] = 0
	var read_index := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

	while read_index < frontier.size():
		var current := frontier[read_index]
		read_index += 1
		var current_distance := int(distances[grid_key(current)])

		for step in steps:
			var next_cell := current + step
			var next_key := grid_key(next_cell)
			if distances.has(next_key):
				continue
			if not bool(is_walkable.call(next_cell, safe_footprint)):
				continue
			distances[next_key] = current_distance + 1
			frontier.append(next_cell)

	return distances


static func get_grid_distance_score(
	distance_map: Dictionary,
	target_cell: Vector2i,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> float:
	if not is_valid_grid_position(target_cell, invalid_grid_position):
		return -1.0
	var target_key := grid_key(target_cell)
	if not distance_map.has(target_key):
		return -1.0
	return float(int(distance_map[target_key]))


static func find_grid_path(
	start_cell: Vector2i,
	target_cell: Vector2i,
	footprint: Vector2i,
	is_walkable: Callable,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_valid_grid_position(start_cell, invalid_grid_position) or not is_valid_grid_position(target_cell, invalid_grid_position):
		return path
	if start_cell == target_cell:
		return path
	if not is_walkable.is_valid():
		return path

	var safe_footprint := get_safe_footprint(footprint)
	if not bool(is_walkable.call(start_cell, safe_footprint)) or not bool(is_walkable.call(target_cell, safe_footprint)):
		return path

	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	came_from[grid_key(start_cell)] = invalid_grid_position
	var read_index := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

	while read_index < frontier.size():
		var current := frontier[read_index]
		read_index += 1

		if current == target_cell:
			break

		for step in steps:
			var next_cell := current + step
			var next_key := grid_key(next_cell)
			if came_from.has(next_key):
				continue
			if not bool(is_walkable.call(next_cell, safe_footprint)):
				continue
			came_from[next_key] = current
			frontier.append(next_cell)

	var target_key := grid_key(target_cell)
	if not came_from.has(target_key):
		return path

	var trace_cell := target_cell
	while trace_cell != start_cell:
		path.insert(0, trace_cell)
		trace_cell = came_from[grid_key(trace_cell)] as Vector2i

	return path


static func find_grid_path_with_fallback(
	start_cell: Vector2i,
	target_cell: Vector2i,
	footprint: Vector2i,
	is_walkable: Callable,
	fallback_is_walkable: Callable,
	invalid_grid_position: Vector2i = INVALID_GRID_POSITION
) -> Array[Vector2i]:
	var path := find_grid_path(start_cell, target_cell, footprint, is_walkable, invalid_grid_position)
	if not path.is_empty() or start_cell == target_cell:
		return path
	if not fallback_is_walkable.is_valid():
		return path
	return find_grid_path(start_cell, target_cell, footprint, fallback_is_walkable, invalid_grid_position)


static func get_side_candidate_cells(
	furniture_cell: Vector2i,
	furniture_footprint: Vector2i,
	actor_footprint: Vector2i
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var safe_furniture_footprint := get_safe_footprint(furniture_footprint)
	var safe_actor_footprint := get_safe_footprint(actor_footprint)

	var min_y := furniture_cell.y - safe_actor_footprint.y + 1
	var max_y := furniture_cell.y + safe_furniture_footprint.y - 1
	for y in range(min_y, max_y + 1):
		candidates.append(Vector2i(furniture_cell.x - safe_actor_footprint.x, y))
		candidates.append(Vector2i(furniture_cell.x + safe_furniture_footprint.x, y))

	var min_x := furniture_cell.x - safe_actor_footprint.x + 1
	var max_x := furniture_cell.x + safe_furniture_footprint.x - 1
	for x in range(min_x, max_x + 1):
		candidates.append(Vector2i(x, furniture_cell.y - safe_actor_footprint.y))
		candidates.append(Vector2i(x, furniture_cell.y + safe_furniture_footprint.y))
	return candidates
