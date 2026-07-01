extends Node2D
class_name BuildFurniturePlacementPreview

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var build_mode_controller_path: NodePath = NodePath("../BuildModeController")
@export var furniture_placement_module_path: NodePath = NodePath("../FurniturePlacementModule")
@export var preview_alpha: float = 0.55
@export var valid_fill_color: Color = Color(0.0, 1.0, 0.18, 0.22)
@export var valid_border_color: Color = Color(0.1, 2.6, 0.35, 0.95)
@export var invalid_fill_color: Color = Color(1.0, 0.05, 0.03, 0.26)
@export var invalid_border_color: Color = Color(2.5, 0.12, 0.08, 0.98)
@export var move_hover_fill_color: Color = Color(1.0, 0.78, 0.05, 0.24)
@export var move_hover_border_color: Color = Color(2.6, 1.85, 0.1, 1.0)
@export var store_fill_color: Color = Color(1.0, 0.08, 0.06, 0.26)
@export var store_border_color: Color = Color(2.6, 0.16, 0.12, 1.0)
@export var locked_furniture_message: String = "使用中の家具は動かせません。"
@export var area_border_width: float = 3.0

var _room_map: RoomMapGridModule
var _controller: BuildModeController
var _placement: FurniturePlacementModule
var _preview_node: Node2D
var _preview_scene: PackedScene
var _grid := Vector2i.ZERO
var _can_place := false
var _moving: Node2D
var _moving_origin := Vector2i.ZERO
var _moving_footprint := Vector2i(1, 1)
var _moving_id: StringName = &""
var _moving_rotation := 0
var _moving_modulate := Color.WHITE


func _ready() -> void:
	z_as_relative = false
	_resolve_refs()
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	_resolve_refs()
	_update_state()
	queue_redraw()


func set_room_map_path(next_room_map_path: NodePath) -> void:
	if room_map_path == next_room_map_path:
		_resolve_refs()
		return
	_cancel_move()
	_hide_preview()
	room_map_path = next_room_map_path
	_room_map = null
	_resolve_refs()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_rotate_current()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_left_click()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_right_click()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _active():
		return
	var mode := _controller.get_tool_mode()
	if mode == BuildModeController.TOOL_MODE_PLACE and _controller.get_selected_furniture_scene() != null:
		_draw_area(_grid, _controller.get_selected_footprint(), _can_place)
	elif mode == BuildModeController.TOOL_MODE_MOVE:
		if _moving != null:
			_draw_area(_grid, _moving_footprint, _can_place)
		else:
			_draw_move_hover_area()
	elif mode == BuildModeController.TOOL_MODE_STORE:
		_draw_store_area()


func _update_state() -> void:
	if not _active():
		_hide_preview()
		_cancel_move()
		return
	_grid = _room_map.world_to_grid(get_global_mouse_position())
	match _controller.get_tool_mode():
		BuildModeController.TOOL_MODE_PLACE:
			_update_place()
		BuildModeController.TOOL_MODE_MOVE:
			_update_move()
		_:
			_hide_preview()
			_can_place = false


func _update_place() -> void:
	var scene := _controller.get_selected_furniture_scene()
	if scene == null:
		_hide_preview()
		_can_place = false
		return
	if scene != _preview_scene:
		_rebuild_preview(scene)
	_sync_preview_grid_cell_size()
	var footprint := _controller.get_selected_footprint()
	_can_place = _placement.can_place_at(_grid, footprint)
	if _preview_node != null:
		_preview_node.visible = true
		_preview_node.global_position = _room_map.grid_to_world_area_center(_grid, footprint)
		_preview_node.rotation_degrees = _controller.get_selected_rotation_degrees()
		_preview_node.modulate = Color(1.0, 1.0, 1.0, preview_alpha)


func _update_move() -> void:
	_hide_preview()
	if _moving == null:
		_can_place = false
		return
	_can_place = _placement.can_place_at(_grid, _moving_footprint)
	_moving.global_position = _room_map.grid_to_world_area_center(_grid, _moving_footprint)
	_moving.rotation_degrees = float(_moving_rotation) * 90.0
	_moving.modulate = Color(1.0, 1.0, 1.0, preview_alpha)


func _left_click() -> void:
	match _controller.get_tool_mode():
		BuildModeController.TOOL_MODE_PLACE:
			_place_selected()
		BuildModeController.TOOL_MODE_MOVE:
			_move_click()
		BuildModeController.TOOL_MODE_STORE:
			_store_click()


func _right_click() -> void:
	match _controller.get_tool_mode():
		BuildModeController.TOOL_MODE_PLACE:
			_clear_selected_furniture()
		BuildModeController.TOOL_MODE_MOVE:
			_cancel_move()


func _place_selected() -> void:
	if not _can_place:
		return
	var scene := _controller.get_selected_furniture_scene()
	if scene == null:
		return
	var footprint := _controller.get_selected_footprint()
	var node := _placement.place_furniture_scene(scene, _grid, footprint, _controller.get_selected_furniture_id())
	if node != null:
		node.rotation_degrees = _controller.get_selected_rotation_degrees()
		node.set_meta("rotation_steps", _controller.get_selected_rotation_steps())


func _store_click() -> void:
	var node := _placement.get_furniture_at(_grid)
	if node != null and not _can_modify_node(node):
		_push_build_message(locked_furniture_message)
		return
	if not _placement.remove_furniture_at(_grid) and node != null:
		_push_build_message(locked_furniture_message)


func _move_click() -> void:
	if _moving == null:
		_start_move()
	else:
		_finish_move()


func _start_move() -> void:
	var target := _placement.get_furniture_at(_grid)
	if target != null and not _can_modify_node(target):
		_push_build_message(locked_furniture_message)
		return
	var node := _placement.take_furniture_at(_grid)
	if node == null:
		return
	_moving = node
	_moving_origin = node.get_meta("grid_position", _grid)
	_moving_footprint = node.get_meta("grid_footprint", Vector2i(1, 1))
	_moving_id = _placement.get_furniture_id(node)
	_moving_rotation = int(node.get_meta("rotation_steps", 0))
	_moving_modulate = node.modulate


func _finish_move() -> void:
	if _moving == null or not _can_place:
		return
	_moving.modulate = _moving_modulate
	_moving.rotation_degrees = float(_moving_rotation) * 90.0
	_moving.set_meta("rotation_steps", _moving_rotation)
	_placement.place_existing_furniture(_moving, _grid, _moving_footprint, _moving_id)
	_clear_move()


func _cancel_move() -> void:
	if _moving == null:
		return
	_moving.modulate = _moving_modulate
	_placement.place_existing_furniture(_moving, _moving_origin, _moving_footprint, _moving_id)
	_clear_move()


func _clear_selected_furniture() -> void:
	if _controller == null:
		return
	if _controller.get_selected_furniture_scene() == null:
		return
	_controller.clear_selected_furniture()
	_hide_preview()
	queue_redraw()


func _rotate_current() -> void:
	if _controller.get_tool_mode() == BuildModeController.TOOL_MODE_PLACE:
		_controller.rotate_selected_furniture(true)
	elif _controller.get_tool_mode() == BuildModeController.TOOL_MODE_MOVE and _moving != null:
		_moving_rotation = (_moving_rotation + 1) % 4
		_moving_footprint = Vector2i(_moving_footprint.y, _moving_footprint.x)


func _draw_area(grid_position: Vector2i, footprint: Vector2i, ok: bool) -> void:
	var rect := _room_map.get_grid_area_rect(grid_position, footprint)
	draw_rect(rect, valid_fill_color if ok else invalid_fill_color, true)
	draw_rect(rect, valid_border_color if ok else invalid_border_color, false, area_border_width)


func _draw_move_hover_area() -> void:
	var node := _placement.get_furniture_at(_grid)
	if node == null:
		return
	var pos: Vector2i = node.get_meta("grid_position", _grid)
	var fp: Vector2i = node.get_meta("grid_footprint", Vector2i(1, 1))
	var rect := _room_map.get_grid_area_rect(pos, fp)
	var can_move := _can_modify_node(node)
	draw_rect(rect, move_hover_fill_color if can_move else invalid_fill_color, true)
	draw_rect(rect, move_hover_border_color if can_move else invalid_border_color, false, area_border_width)


func _draw_store_area() -> void:
	var node := _placement.get_furniture_at(_grid)
	if node == null:
		return
	var pos: Vector2i = node.get_meta("grid_position", _grid)
	var fp: Vector2i = node.get_meta("grid_footprint", Vector2i(1, 1))
	var rect := _room_map.get_grid_area_rect(pos, fp)
	var can_store := _can_modify_node(node)
	draw_rect(rect, store_fill_color if can_store else invalid_fill_color, true)
	draw_rect(rect, store_border_color if can_store else invalid_border_color, false, area_border_width)


func _rebuild_preview(scene: PackedScene) -> void:
	if _preview_node != null:
		_preview_node.queue_free()
	_preview_node = scene.instantiate() as Node2D
	_preview_scene = scene
	if _preview_node != null:
		_preview_node.name = "FurniturePreview"
		_preview_node.z_index = 20
		add_child(_preview_node)
		_sync_preview_grid_cell_size()


func _sync_preview_grid_cell_size() -> void:
	if _preview_node == null or _room_map == null:
		return
	if _preview_node.has_method("set_grid_cell_size"):
		_preview_node.call("set_grid_cell_size", _room_map.get_cell_size())


func _hide_preview() -> void:
	_can_place = false
	if _preview_node != null:
		_preview_node.visible = false


func _clear_move() -> void:
	_moving = null
	_moving_footprint = Vector2i(1, 1)
	_moving_id = &""
	_moving_rotation = 0
	_moving_modulate = Color.WHITE


func _can_modify_node(node: Node2D) -> bool:
	if _placement == null:
		return true
	if not _placement.has_method("can_modify_furniture"):
		return true
	return _placement.call("can_modify_furniture", node) == true


func _push_build_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log") as MessageLogPanel
	if message_log == null:
		return
	message_log.add_message(message)


func _active() -> bool:
	return _controller != null and _room_map != null and _placement != null and _controller.is_build_mode_enabled()


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _controller == null and not build_mode_controller_path.is_empty():
		_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _controller == null:
		_controller = get_tree().get_first_node_in_group(&"build_mode_controller") as BuildModeController
	if _placement == null and not furniture_placement_module_path.is_empty():
		_placement = get_node_or_null(furniture_placement_module_path) as FurniturePlacementModule
	if _placement == null:
		_placement = get_tree().get_first_node_in_group(&"furniture_placement_module") as FurniturePlacementModule
