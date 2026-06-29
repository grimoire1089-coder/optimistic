extends Node2D
class_name BuildGridHighlightOverlay

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var build_mode_controller_path: NodePath = NodePath("../BuildModeController")
@export var highlight_line_width: float = 2.0
@export var highlight_border_width: float = 4.0
@export var highlight_line_color: Color = Color(0.0, 2.8, 2.8, 0.55)
@export var highlight_border_color: Color = Color(0.65, 4.0, 4.0, 1.0)
@export var highlight_fill_color: Color = Color(0.0, 1.0, 1.0, 0.045)

var _room_map: Node
var _build_mode_controller: BuildModeController


func _ready() -> void:
	z_as_relative = false
	_resolve_refs()
	queue_redraw()


func _process(_delta: float) -> void:
	_resolve_refs()
	queue_redraw()


func _draw() -> void:
	if not _is_build_mode_enabled():
		return
	if _room_map == null:
		return
	if not _room_map.has_method("get_grid_rect") or not _room_map.has_method("get_grid_size") or not _room_map.has_method("get_cell_size"):
		return

	var grid_rect: Rect2 = _room_map.call("get_grid_rect")
	var grid_size: Vector2i = _room_map.call("get_grid_size")
	var cell_size: Vector2 = _room_map.call("get_cell_size")
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return

	draw_rect(grid_rect, highlight_fill_color, true)

	for x in range(grid_size.x + 1):
		var draw_x := grid_rect.position.x + float(x) * cell_size.x
		draw_line(Vector2(draw_x, grid_rect.position.y), Vector2(draw_x, grid_rect.end.y), highlight_line_color, highlight_line_width)

	for y in range(grid_size.y + 1):
		var draw_y := grid_rect.position.y + float(y) * cell_size.y
		draw_line(Vector2(grid_rect.position.x, draw_y), Vector2(grid_rect.end.x, draw_y), highlight_line_color, highlight_line_width)

	draw_rect(grid_rect, highlight_border_color, false, highlight_border_width)


func _is_build_mode_enabled() -> bool:
	if _build_mode_controller == null:
		return false
	return _build_mode_controller.is_build_mode_enabled()


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path)
	if _build_mode_controller == null and not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
