extends Node
class_name MainSceneMapRuntimeModule

const INFRASTRUCTURE_ROOM_MAP_SCENE_PATH := "res://Scenes/Maps/InfrastructureRoomMap.tscn"
const CAPSULE_FARM_MUSHROOM_DISTRICT_MAP_SCENE_PATH := "res://Scenes/Maps/CapsuleFarmMushroomDistrictMap.tscn"

@export var robin_room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var infrastructure_room_map_name: StringName = &"InfrastructureRoomMap"
@export var infrastructure_room_map_scene_path: String = INFRASTRUCTURE_ROOM_MAP_SCENE_PATH
@export var capsule_farm_mushroom_district_map_name: StringName = &"CapsuleFarmMushroomDistrictMap"
@export var capsule_farm_mushroom_district_map_scene_path: String = CAPSULE_FARM_MUSHROOM_DISTRICT_MAP_SCENE_PATH

var _robin_room_map: RoomMapGridModule
var _infrastructure_room_map: RoomMapGridModule
var _capsule_farm_mushroom_district_map: RoomMapGridModule


func _ready() -> void:
	ensure_runtime_maps()


func ensure_runtime_maps() -> RoomMapGridModule:
	_resolve_refs()
	if _robin_room_map == null:
		return null

	if _infrastructure_room_map == null:
		_infrastructure_room_map = _instantiate_room_map_scene(infrastructure_room_map_scene_path)
		if _infrastructure_room_map == null:
			_infrastructure_room_map = _create_room_map_fallback(
				String(infrastructure_room_map_name),
				&"infrastructure_room",
				"インフラルーム"
			)
		_add_runtime_map_to_scene(_infrastructure_room_map, _robin_room_map.get_index() + 1)

	if _capsule_farm_mushroom_district_map == null:
		_capsule_farm_mushroom_district_map = _instantiate_room_map_scene(capsule_farm_mushroom_district_map_scene_path)
		if _capsule_farm_mushroom_district_map == null:
			_capsule_farm_mushroom_district_map = _create_room_map_fallback(
				String(capsule_farm_mushroom_district_map_name),
				&"capsule_farm_mushroom_district",
				"カプセルファーム きのこ採取地区"
			)
		var insert_index := _robin_room_map.get_index() + 1
		if _infrastructure_room_map != null:
			insert_index = _infrastructure_room_map.get_index() + 1
		_add_runtime_map_to_scene(_capsule_farm_mushroom_district_map, insert_index)

	return _infrastructure_room_map


func get_robin_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _robin_room_map


func get_infrastructure_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _infrastructure_room_map


func get_capsule_farm_mushroom_district_map() -> RoomMapGridModule:
	_resolve_refs()
	return _capsule_farm_mushroom_district_map


func _instantiate_room_map_scene(scene_path: String) -> RoomMapGridModule:
	if scene_path.is_empty():
		return null
	if not ResourceLoader.exists(scene_path):
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate() as RoomMapGridModule
	return instance


func _add_runtime_map_to_scene(room_map: RoomMapGridModule, insert_index: int) -> void:
	if room_map == null:
		return
	var scene_root := get_parent()
	if scene_root == null:
		return
	if room_map.get_parent() == scene_root:
		return
	scene_root.add_child(room_map)
	scene_root.move_child(room_map, clampi(insert_index, 0, scene_root.get_child_count() - 1))


func _create_room_map_fallback(node_name: String, map_id: StringName, display_name: String) -> RoomMapGridModule:
	var room_map := RoomMapGridModule.new()
	room_map.name = node_name
	room_map.visible = false
	room_map.z_index = _robin_room_map.z_index
	room_map.map_id = map_id
	room_map.map_display_name = display_name
	room_map.buildable = false
	room_map.screen_margin = _robin_room_map.screen_margin
	room_map.bottom_reserved_margin = _robin_room_map.bottom_reserved_margin
	room_map.map_visual_offset = _robin_room_map.map_visual_offset
	room_map.side_ui_margin = _robin_room_map.side_ui_margin
	room_map.cell_size = _robin_room_map.cell_size
	room_map.fixed_grid_size = _robin_room_map.fixed_grid_size
	room_map.fit_cell_size_to_visual_rect = _robin_room_map.fit_cell_size_to_visual_rect
	room_map.show_grid = _robin_room_map.show_grid
	room_map.show_neon_frame = _robin_room_map.show_neon_frame
	room_map.grid_line_width = _robin_room_map.grid_line_width
	room_map.grid_line_color = _robin_room_map.grid_line_color
	room_map.grid_border_width = _robin_room_map.grid_border_width
	room_map.grid_border_color = _robin_room_map.grid_border_color
	room_map.frame_outer_glow_width = _robin_room_map.frame_outer_glow_width
	room_map.frame_middle_glow_width = _robin_room_map.frame_middle_glow_width
	room_map.frame_core_line_width = _robin_room_map.frame_core_line_width

	var furniture_root := Node2D.new()
	furniture_root.name = "FurnitureRoot"
	furniture_root.z_index = 1
	room_map.add_child(furniture_root)
	return room_map


func _resolve_refs() -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	if _robin_room_map == null and not robin_room_map_path.is_empty():
		_robin_room_map = get_node_or_null(robin_room_map_path) as RoomMapGridModule
	if _infrastructure_room_map == null:
		_infrastructure_room_map = scene_root.get_node_or_null(String(infrastructure_room_map_name)) as RoomMapGridModule
	if _capsule_farm_mushroom_district_map == null:
		_capsule_farm_mushroom_district_map = scene_root.get_node_or_null(String(capsule_farm_mushroom_district_map_name)) as RoomMapGridModule
