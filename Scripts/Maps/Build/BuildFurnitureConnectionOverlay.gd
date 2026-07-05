extends Node2D
class_name BuildFurnitureConnectionOverlay

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var furniture_placement_module_path: NodePath = NodePath("../FurniturePlacementModule")
@export var build_mode_controller_path: NodePath = NodePath("../BuildModeController")
@export var show_only_in_build_mode: bool = true
@export var refresh_interval_seconds: float = 0.2
@export var line_color: Color = Color(0.25, 1.0, 0.95, 0.86)
@export var line_glow_color: Color = Color(0.25, 1.0, 0.95, 0.20)
@export var endpoint_color: Color = Color(0.85, 1.0, 1.0, 0.95)
@export var line_width: float = 2.0
@export var glow_width: float = 8.0
@export var endpoint_radius: float = 4.0

var _room_map: RoomMapGridModule
var _placement: FurniturePlacementModule
var _controller: BuildModeController
var _connections: Array[Dictionary] = []
var _refresh_timer: float = 0.0
var _last_layout_version: int = -1
var _was_active: bool = false


func _ready() -> void:
	z_as_relative = false
	_resolve_refs()
	set_process(true)


func _process(delta: float) -> void:
	_resolve_refs()
	var active := _is_active()
	if not active:
		_was_active = false
		_last_layout_version = -1
		if not _connections.is_empty():
			_connections.clear()
			queue_redraw()
		return

	_refresh_timer -= maxf(delta, 0.0)
	if _refresh_timer > 0.0 and _was_active:
		return
	_refresh_timer = maxf(refresh_interval_seconds, 0.05)

	var layout_version := _get_layout_version()
	if _was_active and layout_version == _last_layout_version:
		queue_redraw()
		return

	_was_active = true
	_last_layout_version = layout_version
	_rebuild_connections()
	queue_redraw()


func _draw() -> void:
	if not _is_active():
		return
	for connection in _connections:
		var points := _get_connection_points(connection)
		if points.is_empty():
			continue
		var start := points.get("start", Vector2.ZERO) as Vector2
		var end := points.get("end", Vector2.ZERO) as Vector2
		draw_line(start, end, line_glow_color, maxf(glow_width, line_width))
		draw_line(start, end, line_color, line_width)
		draw_circle(start, endpoint_radius, endpoint_color)
		draw_circle(end, endpoint_radius, endpoint_color)


func _rebuild_connections() -> void:
	_connections.clear()
	if _placement == null:
		return
	var furniture_root := _placement.get_furniture_root()
	if furniture_root == null:
		return

	var chairs: Array[Node2D] = []
	var tables: Array[Node2D] = []
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not furniture.has_meta("grid_position"):
			continue
		if _is_table_furniture(furniture):
			tables.append(furniture)
		elif _is_chair_furniture(furniture):
			chairs.append(furniture)

	for chair in chairs:
		var chair_grid: Vector2i = chair.get_meta("grid_position", Vector2i.ZERO)
		var chair_footprint: Vector2i = chair.get_meta("grid_footprint", _get_furniture_footprint(chair))
		for table in tables:
			var table_grid: Vector2i = table.get_meta("grid_position", Vector2i.ZERO)
			var table_footprint: Vector2i = table.get_meta("grid_footprint", _get_furniture_footprint(table))
			if not _are_facing_each_other(chair_grid, chair_footprint, table_grid, table_footprint):
				continue
			_connections.append({
				"chair_grid": chair_grid,
				"chair_footprint": _safe_footprint(chair_footprint),
				"table_grid": table_grid,
				"table_footprint": _safe_footprint(table_footprint),
			})


func _get_connection_points(connection: Dictionary) -> Dictionary:
	if _room_map == null:
		return {}
	var chair_grid: Vector2i = connection.get("chair_grid", Vector2i.ZERO)
	var chair_footprint: Vector2i = connection.get("chair_footprint", Vector2i(1, 1))
	var table_grid: Vector2i = connection.get("table_grid", Vector2i.ZERO)
	var table_footprint: Vector2i = connection.get("table_footprint", Vector2i(1, 1))

	var chair_rect := _room_map.get_grid_area_rect(chair_grid, chair_footprint)
	var table_rect := _room_map.get_grid_area_rect(table_grid, table_footprint)
	var cell_size := _room_map.get_cell_size()
	var grid_origin := _room_map.get_grid_origin()

	if chair_grid.x + chair_footprint.x == table_grid.x and _ranges_overlap(chair_grid.y, chair_grid.y + chair_footprint.y, table_grid.y, table_grid.y + table_footprint.y):
		var y := _grid_overlap_center_world(chair_grid.y, chair_grid.y + chair_footprint.y, table_grid.y, table_grid.y + table_footprint.y, grid_origin.y, cell_size.y)
		return {"start": Vector2(chair_rect.end.x, y), "end": Vector2(table_rect.position.x, y)}

	if table_grid.x + table_footprint.x == chair_grid.x and _ranges_overlap(chair_grid.y, chair_grid.y + chair_footprint.y, table_grid.y, table_grid.y + table_footprint.y):
		var y := _grid_overlap_center_world(chair_grid.y, chair_grid.y + chair_footprint.y, table_grid.y, table_grid.y + table_footprint.y, grid_origin.y, cell_size.y)
		return {"start": Vector2(chair_rect.position.x, y), "end": Vector2(table_rect.end.x, y)}

	if chair_grid.y + chair_footprint.y == table_grid.y and _ranges_overlap(chair_grid.x, chair_grid.x + chair_footprint.x, table_grid.x, table_grid.x + table_footprint.x):
		var x := _grid_overlap_center_world(chair_grid.x, chair_grid.x + chair_footprint.x, table_grid.x, table_grid.x + table_footprint.x, grid_origin.x, cell_size.x)
		return {"start": Vector2(x, chair_rect.end.y), "end": Vector2(x, table_rect.position.y)}

	if table_grid.y + table_footprint.y == chair_grid.y and _ranges_overlap(chair_grid.x, chair_grid.x + chair_footprint.x, table_grid.x, table_grid.x + table_footprint.x):
		var x := _grid_overlap_center_world(chair_grid.x, chair_grid.x + chair_footprint.x, table_grid.x, table_grid.x + table_footprint.x, grid_origin.x, cell_size.x)
		return {"start": Vector2(x, chair_rect.position.y), "end": Vector2(x, table_rect.end.y)}

	return {}


func _are_facing_each_other(chair_grid: Vector2i, chair_footprint: Vector2i, table_grid: Vector2i, table_footprint: Vector2i) -> bool:
	var safe_chair_footprint := _safe_footprint(chair_footprint)
	var safe_table_footprint := _safe_footprint(table_footprint)
	var chair_left := chair_grid.x
	var chair_right := chair_grid.x + safe_chair_footprint.x
	var chair_top := chair_grid.y
	var chair_bottom := chair_grid.y + safe_chair_footprint.y
	var table_left := table_grid.x
	var table_right := table_grid.x + safe_table_footprint.x
	var table_top := table_grid.y
	var table_bottom := table_grid.y + safe_table_footprint.y

	if chair_right == table_left or table_right == chair_left:
		return _ranges_overlap(chair_top, chair_bottom, table_top, table_bottom)
	if chair_bottom == table_top or table_bottom == chair_top:
		return _ranges_overlap(chair_left, chair_right, table_left, table_right)
	return false


func _ranges_overlap(a_start: int, a_end: int, b_start: int, b_end: int) -> bool:
	return maxi(a_start, b_start) < mini(a_end, b_end)


func _grid_overlap_center_world(a_start: int, a_end: int, b_start: int, b_end: int, origin: float, cell_axis_size: float) -> float:
	var overlap_start := maxi(a_start, b_start)
	var overlap_end := mini(a_end, b_end)
	return origin + (float(overlap_start) + float(overlap_end)) * 0.5 * cell_axis_size


func _is_chair_furniture(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_be_sat_on") and furniture.call("can_be_sat_on") == true:
		return true
	if furniture.has_method("is_stool") and furniture.call("is_stool") == true:
		return true
	return _get_furniture_id(furniture) == &"stool"


func _is_table_furniture(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("is_table") and furniture.call("is_table") == true:
		return true
	return _get_furniture_id(furniture) == &"table"


func _get_furniture_id(furniture: Node2D) -> StringName:
	if _placement != null:
		return _placement.get_furniture_id(furniture)
	if furniture != null and furniture.has_meta("furniture_id"):
		return furniture.get_meta("furniture_id", &"") as StringName
	return &""


func _get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if _placement != null:
		return _placement.get_furniture_footprint(furniture, Vector2i(1, 1))
	if furniture != null and furniture.has_method("get_grid_footprint"):
		return furniture.call("get_grid_footprint") as Vector2i
	return Vector2i(1, 1)


func _safe_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))


func _get_layout_version() -> int:
	if _placement == null:
		return -1
	return _placement.get_layout_version()


func _is_active() -> bool:
	if _room_map == null or _placement == null:
		return false
	if not show_only_in_build_mode:
		return true
	if _controller == null:
		return false
	return _controller.is_build_mode_enabled()


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _placement == null and not furniture_placement_module_path.is_empty():
		_placement = get_node_or_null(furniture_placement_module_path) as FurniturePlacementModule
	if _controller == null and not build_mode_controller_path.is_empty():
		_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _controller == null:
		_controller = get_tree().get_first_node_in_group(&"build_mode_controller") as BuildModeController
