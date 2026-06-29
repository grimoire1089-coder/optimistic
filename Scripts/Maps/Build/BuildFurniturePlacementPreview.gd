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
@export var area_border_width: float = 3.0

var _room_map: RoomMapGridModule
var _build_mode_controller: BuildModeController
var _furniture_placement_module: FurniturePlacementModule
var _preview_node: Node2D
var _preview_scene: PackedScene
var _current_grid_position := Vector2i.ZERO
var _current_can_place: bool = false


func _ready() -> void:
	z_as_relative = false
	_resolve_refs()
	set_process_unhandled_input(true)
	queue_redraw()


func _process(_delta: float) -> void:
	_resolve_refs()
	_update_preview()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_ready_to_place():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_place_selected_furniture()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _is_ready_to_preview():
		return
	if _room_map == null:
		return

	var footprint := _build_mode_controller.get_selected_footprint()
	var area_rect := _room_map.get_grid_area_rect(_current_grid_position, footprint)
	var fill_color := valid_fill_color if _current_can_place else invalid_fill_color
	var border_color := valid_border_color if _current_can_place else invalid_border_color
	draw_rect(area_rect, fill_color, true)
	draw_rect(area_rect, border_color, false, area_border_width)


func _update_preview() -> void:
	if not _is_ready_to_preview():
		_hide_preview()
		return

	var selected_scene := _build_mode_controller.get_selected_furniture_scene()
	if selected_scene != _preview_scene:
		_rebuild_preview(selected_scene)

	var footprint := _build_mode_controller.get_selected_footprint()
	_current_grid_position = _room_map.world_to_grid(get_global_mouse_position())
	_current_can_place = _furniture_placement_module.can_place_at(_current_grid_position, footprint)

	if _preview_node != null:
		_preview_node.visible = true
		_preview_node.global_position = _room_map.grid_to_world_area_center(_current_grid_position, footprint)
		_preview_node.modulate = Color(1.0, 1.0, 1.0, preview_alpha)


func _try_place_selected_furniture() -> void:
	if not _current_can_place:
		return
	var selected_scene := _build_mode_controller.get_selected_furniture_scene()
	if selected_scene == null:
		return
	var footprint := _build_mode_controller.get_selected_footprint()
	var furniture_id := _build_mode_controller.get_selected_furniture_id()
	_furniture_placement_module.place_furniture_scene(selected_scene, _current_grid_position, footprint, furniture_id)


func _rebuild_preview(selected_scene: PackedScene) -> void:
	if _preview_node != null:
		_preview_node.queue_free()
		_preview_node = null
	_preview_scene = selected_scene
	if selected_scene == null:
		return

	var instance := selected_scene.instantiate()
	_preview_node = instance as Node2D
	if _preview_node == null:
		instance.queue_free()
		return
	_preview_node.name = "FurniturePreview"
	_preview_node.modulate = Color(1.0, 1.0, 1.0, preview_alpha)
	_preview_node.z_index = 20
	add_child(_preview_node)


func _hide_preview() -> void:
	_current_can_place = false
	if _preview_node != null:
		_preview_node.visible = false


func _is_ready_to_preview() -> bool:
	return (
		_build_mode_controller != null
		and _room_map != null
		and _furniture_placement_module != null
		and _build_mode_controller.is_build_mode_enabled()
		and _build_mode_controller.get_selected_furniture_scene() != null
	)


func _is_ready_to_place() -> bool:
	return _is_ready_to_preview() and _current_can_place


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _build_mode_controller == null and not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path) as FurniturePlacementModule
