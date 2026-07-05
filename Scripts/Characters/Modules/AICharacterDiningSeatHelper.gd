extends RefCounted
class_name AICharacterDiningSeatHelper

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)


static func find_best_connected_chair(
	furniture_root: Node,
	room_map: RoomMapGridModule,
	body_position: Vector2,
	actor_footprint: Vector2i,
	is_target_cell_walkable: Callable,
	minimum_overlap_cells: int = 2,
	allow_occupied: bool = false
) -> Dictionary:
	if furniture_root == null or room_map == null:
		return {}

	var chairs: Array[Node2D] = []
	var tables: Array[Node2D] = []
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not furniture.has_meta("grid_position"):
			continue
		if is_table_furniture(furniture):
			tables.append(furniture)
		elif is_chair_furniture(furniture):
			chairs.append(furniture)

	var best: Dictionary = {}
	var best_score := INF
	for chair in chairs:
		var chair_cell := get_furniture_grid_position(chair)
		if not is_valid_grid_position(chair_cell):
			continue
		var chair_footprint := get_furniture_footprint(chair)
		var connected_table := find_connected_table_for_chair(chair, tables, minimum_overlap_cells)
		if connected_table == null:
			continue
		var use_cell := get_chair_use_cell(room_map, chair, actor_footprint, is_target_cell_walkable, allow_occupied)
		if not is_valid_grid_position(use_cell):
			continue
		var use_position := room_map.grid_to_world_area_center(use_cell, get_safe_footprint(actor_footprint))
		var score := body_position.distance_squared_to(use_position)
		if best.is_empty() or score < best_score:
			best_score = score
			best = {
				"chair": chair,
				"table": connected_table,
				"use_cell": use_cell,
				"chair_cell": chair_cell,
				"chair_footprint": chair_footprint,
				"table_cell": get_furniture_grid_position(connected_table),
				"table_footprint": get_furniture_footprint(connected_table),
			}
	return best


static func find_connected_table_for_chair(chair: Node2D, tables: Array[Node2D], minimum_overlap_cells: int = 2) -> Node2D:
	if chair == null:
		return null
	var chair_cell := get_furniture_grid_position(chair)
	if not is_valid_grid_position(chair_cell):
		return null
	var chair_footprint := get_furniture_footprint(chair)
	for table in tables:
		if table == null:
			continue
		var table_cell := get_furniture_grid_position(table)
		if not is_valid_grid_position(table_cell):
			continue
		if are_connected(chair_cell, chair_footprint, table_cell, get_furniture_footprint(table), minimum_overlap_cells):
			return table
	return null


static func are_connected(chair_grid: Vector2i, chair_footprint: Vector2i, table_grid: Vector2i, table_footprint: Vector2i, minimum_overlap_cells: int = 2) -> bool:
	var safe_chair_footprint := get_safe_footprint(chair_footprint)
	var safe_table_footprint := get_safe_footprint(table_footprint)
	var chair_left := chair_grid.x
	var chair_right := chair_grid.x + safe_chair_footprint.x
	var chair_top := chair_grid.y
	var chair_bottom := chair_grid.y + safe_chair_footprint.y
	var table_left := table_grid.x
	var table_right := table_grid.x + safe_table_footprint.x
	var table_top := table_grid.y
	var table_bottom := table_grid.y + safe_table_footprint.y

	if chair_right == table_left or table_right == chair_left:
		return ranges_overlap_by_required_cells(chair_top, chair_bottom, table_top, table_bottom, minimum_overlap_cells)
	if chair_bottom == table_top or table_bottom == chair_top:
		return ranges_overlap_by_required_cells(chair_left, chair_right, table_left, table_right, minimum_overlap_cells)
	return false


static func ranges_overlap_by_required_cells(a_start: int, a_end: int, b_start: int, b_end: int, minimum_overlap_cells: int = 2) -> bool:
	var overlap_cells := mini(a_end, b_end) - maxi(a_start, b_start)
	return overlap_cells >= maxi(minimum_overlap_cells, 1)


static func get_chair_use_cell(
	room_map: RoomMapGridModule,
	chair: Node2D,
	actor_footprint: Vector2i,
	is_target_cell_walkable: Callable,
	allow_occupied: bool = false
) -> Vector2i:
	if room_map == null or chair == null:
		return INVALID_GRID_POSITION
	var chair_cell := get_furniture_grid_position(chair)
	if not is_valid_grid_position(chair_cell):
		return INVALID_GRID_POSITION
	var chair_footprint := get_furniture_footprint(chair)
	var safe_actor_footprint := get_safe_footprint(actor_footprint)
	var candidates := AICharacterGridMovementHelper.get_side_candidate_cells(chair_cell, chair_footprint, safe_actor_footprint)
	for candidate in candidates:
		if is_target_cell_walkable.call(candidate, safe_actor_footprint, allow_occupied) == true:
			return candidate
	return INVALID_GRID_POSITION


static func get_chair_sit_position(chair: Node2D, fallback_position: Vector2) -> Vector2:
	if chair == null:
		return fallback_position
	if chair.has_method("get_sit_target_global_position"):
		var sit_position: Variant = chair.call("get_sit_target_global_position")
		if sit_position is Vector2:
			return sit_position
	return chair.global_position


static func is_chair_furniture(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_be_sat_on") and furniture.call("can_be_sat_on") == true:
		return true
	if furniture.has_method("is_stool") and furniture.call("is_stool") == true:
		return true
	return get_furniture_id(furniture) == &"stool"


static func is_table_furniture(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("is_table") and furniture.call("is_table") == true:
		return true
	return get_furniture_id(furniture) == &"table"


static func get_furniture_id(furniture: Node2D) -> StringName:
	if furniture == null:
		return &""
	if furniture.has_meta("furniture_id"):
		var meta_id: Variant = furniture.get_meta("furniture_id", &"")
		if meta_id is StringName:
			return meta_id
		if meta_id is String:
			return StringName(meta_id)
	for property_info in furniture.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) != &"furniture_id":
			continue
		var property_id: Variant = furniture.get("furniture_id")
		if property_id is StringName:
			return property_id
		if property_id is String:
			return StringName(property_id)
	return &""


static func get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null:
		return INVALID_GRID_POSITION
	if not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


static func get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if furniture == null:
		return Vector2i(1, 1)
	if furniture.has_meta("grid_footprint"):
		var meta_footprint: Variant = furniture.get_meta("grid_footprint", Vector2i(1, 1))
		if meta_footprint is Vector2i:
			var typed_meta_footprint: Vector2i = meta_footprint
			return get_safe_footprint(typed_meta_footprint)
	if furniture.has_method("get_grid_footprint"):
		var method_footprint: Variant = furniture.call("get_grid_footprint")
		if method_footprint is Vector2i:
			var typed_method_footprint: Vector2i = method_footprint
			return get_safe_footprint(typed_method_footprint)
	return Vector2i(1, 1)


static func get_safe_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))


static func is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_GRID_POSITION
