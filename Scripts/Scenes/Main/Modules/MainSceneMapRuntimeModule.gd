extends Node
class_name MainSceneMapRuntimeModule

const INFRASTRUCTURE_ROOM_MAP_SCENE_PATH := "res://Scenes/Maps/InfrastructureRoomMap.tscn"

@export var robin_room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var infrastructure_room_map_name: StringName = &"InfrastructureRoomMap"
@export var infrastructure_room_map_scene_path: String = INFRASTRUCTURE_ROOM_MAP_SCENE_PATH

var _robin_room_map: RoomMapGridModule
var _infrastructure_room_map: RoomMapGridModule


func _ready() -> void:
	ensure_runtime_maps()


func ensure_runtime_maps() -> RoomMapGridModule:
	_resolve_refs()
	if _infrastructure_room_map != null:
		return _infrastructure_room_map
	if _robin_room_map == null:
		return null

	_infrastructure_room_map = _instantiate_infrastructure_room_map_scene()
	if _infrastructure_room_map == null:
		_infrastructure_room_map = _create_infrastructure_room_map_fallback()
	if _infrastructure_room_map == null:
		return null

	var scene_root := get_parent()
	if scene_root == null:
		return _infrastructure_room_map

	scene_root.add_child(_infrastructure_room_map)
	scene_root.move_child(_infrastructure_room_map, _robin_room_map.get_index() + 1)
	return _infrastructure_room_map


func get_robin_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _robin_room_map


func get_infrastructure_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _infrastructure_room_map


func _instantiate_infrastructure_room_map_scene() -> RoomMapGridModule:
	if infrastructure_room_map_scene_path.is_empty():
		return null
	if not ResourceLoader.exists(infrastructure_room_map_scene_path):
		return null
	var scene := load(infrastructure_room_map_scene_path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate() as RoomMapGridModule
	return instance


func _create_infrastructure_room_map_fallback() -> RoomMapGridModule:
	var infrastructure_room_map := RoomMapGridModule.new()
	infrastructure_room_map.name = String(infrastructure_room_map_name)
	infrastructure_room_map.visible = false
	infrastructure_room_map.z_index = _robin_room_map.z_index
	infrastructure_room_map.map_id = &"infrastructure_room"
	infrastructure_room_map.map_display_name = "インフラルーム"
	infrastructure_room_map.buildable = false
	infrastructure_room_map.screen_margin = _robin_room_map.screen_margin
	infrastructure_room_map.bottom_reserved_margin = _robin_room_map.bottom_reserved_margin
	infrastructure_room_map.map_visual_offset = _robin_room_map.map_visual_offset
	infrastructure_room_map.side_ui_margin = _robin_room_map.side_ui_margin
	infrastructure_room_map.cell_size = _robin_room_map.cell_size
	infrastructure_room_map.fixed_grid_size = _robin_room_map.fixed_grid_size
	infrastructure_room_map.fit_cell_size_to_visual_rect = _robin_room_map.fit_cell_size_to_visual_rect
	infrastructure_room_map.show_grid = _robin_room_map.show_grid
	infrastructure_room_map.show_neon_frame = _robin_room_map.show_neon_frame
	infrastructure_room_map.grid_line_width = _robin_room_map.grid_line_width
	infrastructure_room_map.grid_line_color = _robin_room_map.grid_line_color
	infrastructure_room_map.grid_border_width = _robin_room_map.grid_border_width
	infrastructure_room_map.grid_border_color = _robin_room_map.grid_border_color
	infrastructure_room_map.frame_outer_glow_width = _robin_room_map.frame_outer_glow_width
	infrastructure_room_map.frame_middle_glow_width = _robin_room_map.frame_middle_glow_width
	infrastructure_room_map.frame_core_line_width = _robin_room_map.frame_core_line_width

	var furniture_root := Node2D.new()
	furniture_root.name = "FurnitureRoot"
	furniture_root.z_index = 1
	infrastructure_room_map.add_child(furniture_root)
	return infrastructure_room_map


func _resolve_refs() -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	if _robin_room_map == null and not robin_room_map_path.is_empty():
		_robin_room_map = get_node_or_null(robin_room_map_path) as RoomMapGridModule
	if _infrastructure_room_map == null:
		_infrastructure_room_map = scene_root.get_node_or_null(String(infrastructure_room_map_name)) as RoomMapGridModule
