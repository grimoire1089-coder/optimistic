extends Node2D
class_name RoomMapGridModule

signal map_rect_changed(visual_rect: Rect2, grid_rect: Rect2, grid_size: Vector2i)

@export var map_id: StringName = &"robin_room"
@export var map_display_name: String = "ロビンの部屋"
@export var buildable: bool = true
@export var screen_margin: float = 96.0
@export var bottom_reserved_margin: float = 0.0
@export var map_visual_offset: Vector2 = Vector2.ZERO
@export var side_ui_margin: float = 280.0
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var fixed_grid_size: Vector2i = Vector2i.ZERO
@export var fit_cell_size_to_visual_rect: bool = false
@export var show_grid: bool = true
@export var show_neon_frame: bool = false
@export var grid_line_width: float = 1.0
@export var grid_line_color: Color = Color(0.0, 1.2, 1.2, 0.22)
@export var grid_border_width: float = 2.0
@export var grid_border_color: Color = Color(0.0, 2.0, 2.0, 0.38)
@export var frame_outer_glow_width: float = 24.0
@export var frame_middle_glow_width: float = 12.0
@export var frame_core_line_width: float = 4.0
@export var show_ai_movement_debug_highlight: bool = true
@export var ai_movement_path_fill_color: Color = Color(0.0, 1.0, 1.0, 0.18)
@export var ai_movement_path_border_color: Color = Color(0.0, 2.0, 2.0, 0.55)
@export var ai_movement_next_fill_color: Color = Color(1.0, 0.95, 0.1, 0.25)
@export var ai_movement_next_border_color: Color = Color(1.0, 1.8, 0.2, 0.85)
@export var ai_movement_target_fill_color: Color = Color(1.0, 0.15, 0.95, 0.20)
@export var ai_movement_target_border_color: Color = Color(1.0, 0.3, 1.6, 0.85)
@export var ai_movement_footprint_fill_color: Color = Color(0.2, 1.0, 0.35, 0.12)
@export var ai_movement_footprint_border_color: Color = Color(0.4, 1.8, 0.6, 0.62)

var _last_visual_rect := Rect2()
var _last_grid_rect := Rect2()
var _last_grid_size := Vector2i.ZERO


func _ready() -> void:
	z_as_relative = false
	_sync_map_state(true)
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_map_state(false)
	queue_redraw()


func is_buildable() -> bool:
	return buildable


func get_visual_map_rect() -> Rect2:
	var rect := get_viewport().get_visible_rect()
	var horizontal_margin := maxf(side_ui_margin, 0.0)
	var vertical_margin := maxf(screen_margin, 0.0)
	var min_pos := rect.position + Vector2(horizontal_margin, vertical_margin)
	var max_pos := rect.end - Vector2(horizontal_margin, vertical_margin)
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
	var square_area_position := min_pos + (available_size - square_area_size) * 0.5 + map_visual_offset
	return Rect2(square_area_position, square_area_size)


func get_grid_size() -> Vector2i:
	if fixed_grid_size.x > 0 and fixed_grid_size.y > 0:
		return fixed_grid_size

	var visual_rect := get_visual_map_rect()
	var safe_cell_size := _get_safe_cell_size()
	return Vector2i(
		maxi(1, floori(visual_rect.size.x / safe_cell_size.x)),
		maxi(1, floori(visual_rect.size.y / safe_cell_size.y))
	)


func get_grid_rect() -> Rect2:
	var visual_rect := get_visual_map_rect()
	var grid_size := get_grid_size()
	var safe_cell_size := _get_safe_cell_size()
	var grid_pixel_size := Vector2(float(grid_size.x), float(grid_size.y)) * safe_cell_size
	var grid_position := visual_rect.position + (visual_rect.size - grid_pixel_size) * 0.5
	return Rect2(grid_position, grid_pixel_size)


func get_grid_origin() -> Vector2:
	return get_grid_rect().position


func get_cell_size() -> Vector2:
	return _get_safe_cell_size()


func grid_to_world_cell_center(grid_position: Vector2i) -> Vector2:
	var cell_rect := get_grid_cell_rect(grid_position)
	return cell_rect.position + cell_rect.size * 0.5


func grid_to_world_cell_position(grid_position: Vector2i) -> Vector2:
	return get_grid_cell_rect(grid_position).position


func grid_to_world_area_center(grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> Vector2:
	var area_rect := get_grid_area_rect(grid_position, footprint)
	return area_rect.position + area_rect.size * 0.5


func get_grid_cell_rect(grid_position: Vector2i) -> Rect2:
	var grid_origin := get_grid_origin()
	var safe_cell_size := _get_safe_cell_size()
	var cell_position := grid_origin + Vector2(float(grid_position.x), float(grid_position.y)) * safe_cell_size
	return Rect2(cell_position, safe_cell_size)


func get_grid_area_rect(grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> Rect2:
	var safe_footprint := Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	var area_position := grid_to_world_cell_position(grid_position)
	var area_size := Vector2(float(safe_footprint.x), float(safe_footprint.y)) * _get_safe_cell_size()
	return Rect2(area_position, area_size)


func world_to_grid(world_position: Vector2) -> Vector2i:
	var grid_origin := get_grid_origin()
	var safe_cell_size := _get_safe_cell_size()
	var local_position := world_position - grid_origin
	return Vector2i(
		floori(local_position.x / safe_cell_size.x),
		floori(local_position.y / safe_cell_size.y)
	)


func snap_world_position_to_grid_center(world_position: Vector2) -> Vector2:
	return grid_to_world_cell_center(world_to_grid(world_position))


func is_grid_position_inside(grid_position: Vector2i) -> bool:
	var grid_size := get_grid_size()
	return grid_position.x >= 0 and grid_position.y >= 0 and grid_position.x < grid_size.x and grid_position.y < grid_size.y


func is_grid_area_inside(grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> bool:
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	var grid_size := get_grid_size()
	return (
		grid_position.x >= 0
		and grid_position.y >= 0
		and grid_position.x + footprint.x <= grid_size.x
		and grid_position.y + footprint.y <= grid_size.y
	)


func _draw() -> void:
	var visual_rect := get_visual_map_rect()
	if visual_rect.size.x <= 0.0 or visual_rect.size.y <= 0.0:
		return

	if show_neon_frame:
		_draw_neon_frame(visual_rect)

	if show_grid:
		_draw_grid()

	if show_ai_movement_debug_highlight:
		_draw_ai_movement_debug_highlight()


func _draw_grid() -> void:
	var grid_rect := get_grid_rect()
	var grid_size := get_grid_size()
	var safe_cell_size := _get_safe_cell_size()

	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return

	for x in range(grid_size.x + 1):
		var draw_x := grid_rect.position.x + float(x) * safe_cell_size.x
		draw_line(
			Vector2(draw_x, grid_rect.position.y),
			Vector2(draw_x, grid_rect.end.y),
			grid_line_color,
			grid_line_width
		)

	for y in range(grid_size.y + 1):
		var draw_y := grid_rect.position.y + float(y) * safe_cell_size.y
		draw_line(
			Vector2(grid_rect.position.x, draw_y),
			Vector2(grid_rect.end.x, draw_y),
			grid_line_color,
			grid_line_width
		)

	draw_rect(grid_rect, grid_border_color, false, grid_border_width)


func _draw_ai_movement_debug_highlight() -> void:
	var sleep_behavior := _get_first_sleep_behavior_with_path_debug()
	if sleep_behavior == null:
		return
	if sleep_behavior.has_method("is_active") and sleep_behavior.call("is_active") != true:
		return
	if sleep_behavior.has_method("is_sleeping") and sleep_behavior.call("is_sleeping") == true:
		return

	var footprint := Vector2i(1, 1)
	if sleep_behavior.has_method("get_debug_actor_footprint"):
		footprint = sleep_behavior.call("get_debug_actor_footprint") as Vector2i

	var path_cells: Array = []
	if sleep_behavior.has_method("get_debug_path_cells"):
		path_cells = sleep_behavior.call("get_debug_path_cells") as Array

	for cell_value in path_cells:
		if not (cell_value is Vector2i):
			continue
		_draw_grid_area_highlight(cell_value as Vector2i, footprint, ai_movement_path_fill_color, ai_movement_path_border_color, 1.0)

	if sleep_behavior.has_method("get_debug_next_cell"):
		var next_cell: Vector2i = sleep_behavior.call("get_debug_next_cell")
		if is_grid_area_inside(next_cell, footprint):
			_draw_grid_area_highlight(next_cell, footprint, ai_movement_next_fill_color, ai_movement_next_border_color, 3.0)

	if sleep_behavior.has_method("get_debug_target_cell"):
		var target_cell: Vector2i = sleep_behavior.call("get_debug_target_cell")
		if is_grid_area_inside(target_cell, footprint):
			_draw_grid_area_highlight(target_cell, footprint, ai_movement_target_fill_color, ai_movement_target_border_color, 3.0)

	var actor := sleep_behavior.get_parent() as Node2D
	if actor != null:
		var actor_top_left := world_to_grid(actor.global_position) - Vector2i(floori(float(footprint.x) * 0.5), floori(float(footprint.y) * 0.5))
		if is_grid_area_inside(actor_top_left, footprint):
			_draw_grid_area_highlight(actor_top_left, footprint, ai_movement_footprint_fill_color, ai_movement_footprint_border_color, 2.0)


func _draw_grid_area_highlight(grid_position: Vector2i, footprint: Vector2i, fill_color: Color, border_color: Color, border_width: float) -> void:
	if not is_grid_area_inside(grid_position, footprint):
		return
	var rect := get_grid_area_rect(grid_position, footprint).grow(-2.0)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, border_width)


func _get_first_sleep_behavior_with_path_debug() -> Node:
	var nodes := get_tree().get_nodes_in_group(&"ai_sleep_behavior")
	for node in nodes:
		if node is Node and node.has_method("get_debug_path_cells"):
			return node
	var root := get_tree().current_scene
	if root == null:
		return null
	return _find_first_sleep_behavior_recursive(root)


func _find_first_sleep_behavior_recursive(node: Node) -> Node:
	if node.has_method("get_debug_path_cells") and node.has_method("get_debug_target_cell"):
		return node
	for child in node.get_children():
		var found := _find_first_sleep_behavior_recursive(child)
		if found != null:
			return found
	return null


func _draw_neon_frame(visual_rect: Rect2) -> void:
	var outer_color := Color(0.0, 1.4, 1.4, 0.20)
	var middle_color := Color(0.0, 2.2, 2.2, 0.48)
	var core_color := Color(0.85, 4.0, 4.0, 1.0)
	_draw_outside_rect_stroke(visual_rect, outer_color, frame_outer_glow_width)
	_draw_outside_rect_stroke(visual_rect, middle_color, frame_middle_glow_width)
	draw_rect(visual_rect, core_color, false, frame_core_line_width)


func _draw_outside_rect_stroke(base_rect: Rect2, color: Color, width: float) -> void:
	var source_width := maxf(width, 0.0)
	if source_width <= 0.0:
		return
	var stroke_width := source_width * 0.5
	draw_rect(base_rect.grow(stroke_width * 0.5), color, false, stroke_width)


func _sync_map_state(force_emit: bool) -> void:
	var visual_rect := get_visual_map_rect()
	var grid_rect := get_grid_rect()
	var grid_size := get_grid_size()

	if force_emit or not visual_rect.is_equal_approx(_last_visual_rect) or not grid_rect.is_equal_approx(_last_grid_rect) or grid_size != _last_grid_size:
		_last_visual_rect = visual_rect
		_last_grid_rect = grid_rect
		_last_grid_size = grid_size
		map_rect_changed.emit(visual_rect, grid_rect, grid_size)


func _get_safe_cell_size() -> Vector2:
	var safe_base_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	if not fit_cell_size_to_visual_rect:
		return safe_base_cell_size
	if fixed_grid_size.x <= 0 or fixed_grid_size.y <= 0:
		return safe_base_cell_size

	var visual_rect := get_visual_map_rect()
	if visual_rect.size.x <= 0.0 or visual_rect.size.y <= 0.0:
		return safe_base_cell_size

	return Vector2(
		maxf(visual_rect.size.x / float(fixed_grid_size.x), 1.0),
		maxf(visual_rect.size.y / float(fixed_grid_size.y), 1.0)
	)
