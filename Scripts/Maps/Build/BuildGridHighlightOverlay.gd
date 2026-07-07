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
	_connect_signals()
	_sync_visibility()
	queue_redraw()
	_sync_process_enabled()


func _exit_tree() -> void:
	_disconnect_room_map_signal()
	_disconnect_build_mode_signal()


func _process(_delta: float) -> void:
	_resolve_refs()
	_connect_signals()
	_sync_visibility()
	_sync_process_enabled()


func set_room_map_path(next_room_map_path: NodePath) -> void:
	if room_map_path == next_room_map_path:
		_resolve_refs()
		_connect_room_map_signal()
		_sync_process_enabled()
		return
	_disconnect_room_map_signal()
	room_map_path = next_room_map_path
	_room_map = null
	_resolve_refs()
	_connect_room_map_signal()
	queue_redraw()
	_sync_process_enabled()


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


func _on_build_mode_changed(_enabled: bool) -> void:
	_sync_visibility()
	queue_redraw()


func _on_map_rect_changed(_visual_rect: Rect2, _grid_rect: Rect2, _grid_size: Vector2i) -> void:
	if visible:
		queue_redraw()


func _sync_visibility() -> void:
	var next_visible := _is_build_mode_enabled()
	if visible == next_visible:
		return
	visible = next_visible
	queue_redraw()


func _sync_process_enabled() -> void:
	set_process(_room_map == null or _build_mode_controller == null)


func _is_build_mode_enabled() -> bool:
	if _build_mode_controller == null:
		return false
	return _build_mode_controller.is_build_mode_enabled()


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path)
	if _build_mode_controller == null and not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController


func _connect_signals() -> void:
	_connect_build_mode_signal()
	_connect_room_map_signal()


func _connect_build_mode_signal() -> void:
	if _build_mode_controller == null:
		return
	var callable := Callable(self, "_on_build_mode_changed")
	if not _build_mode_controller.build_mode_changed.is_connected(callable):
		_build_mode_controller.build_mode_changed.connect(callable)


func _disconnect_build_mode_signal() -> void:
	if _build_mode_controller == null:
		return
	var callable := Callable(self, "_on_build_mode_changed")
	if _build_mode_controller.build_mode_changed.is_connected(callable):
		_build_mode_controller.build_mode_changed.disconnect(callable)


func _connect_room_map_signal() -> void:
	if _room_map == null:
		return
	if not _room_map.has_signal(&"map_rect_changed"):
		return
	var callable := Callable(self, "_on_map_rect_changed")
	if not _room_map.is_connected(&"map_rect_changed", callable):
		_room_map.connect(&"map_rect_changed", callable)


func _disconnect_room_map_signal() -> void:
	if _room_map == null:
		return
	if not _room_map.has_signal(&"map_rect_changed"):
		return
	var callable := Callable(self, "_on_map_rect_changed")
	if _room_map.is_connected(&"map_rect_changed", callable):
		_room_map.disconnect(&"map_rect_changed", callable)
