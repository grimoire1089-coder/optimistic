extends Node
class_name MainSceneMapEntranceModule

const MAP_ID_ROBIN_ROOM: StringName = &"robin_room"
const MAP_ID_INFRASTRUCTURE_ROOM: StringName = &"infrastructure_room"
const BUILD_LOCK_META := &"build_locked_by_sleep"
const DEFAULT_ENTRANCE_SCENE_PATH := "res://Scenes/Maps/Furniture/Utility/EntranceFurniture.tscn"

@export var robin_room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var infrastructure_room_map_path: NodePath = NodePath("../InfrastructureRoomMap")
@export var furniture_placement_module_path: NodePath = NodePath("../FurniturePlacementModule")
@export var entrance_scene_path: String = DEFAULT_ENTRANCE_SCENE_PATH
@export var entrance_footprint: Vector2i = Vector2i(3, 1)
@export var robin_room_entrance_grid_position: Vector2i = Vector2i(6, 14)
@export var infrastructure_room_entrance_grid_position: Vector2i = Vector2i(6, 14)

var _robin_room_map: RoomMapGridModule
var _infrastructure_room_map: RoomMapGridModule
var _furniture_placement_module: FurniturePlacementModule
var _entrance_scene: PackedScene
var _sync_timer := 0.0
var _runtime_entrances_ready := false


func _ready() -> void:
	_resolve_refs()
	ensure_runtime_entrances()
	set_process(true)


func _process(delta: float) -> void:
	_resolve_refs()
	if not _runtime_entrances_ready:
		ensure_runtime_entrances()
	_sync_timer += maxf(delta, 0.0)
	if _sync_timer >= 0.25:
		_sync_timer = 0.0
		_sync_entrance_layouts()


func ensure_runtime_entrances() -> void:
	_resolve_refs()
	var robin_entrance := _ensure_entrance_for_map(
		_robin_room_map,
		"RobinRoomEntrance",
		MAP_ID_INFRASTRUCTURE_ROOM,
		robin_room_entrance_grid_position
	)
	var infrastructure_entrance := _ensure_entrance_for_map(
		_infrastructure_room_map,
		"InfrastructureRoomEntrance",
		MAP_ID_ROBIN_ROOM,
		infrastructure_room_entrance_grid_position
	)
	_runtime_entrances_ready = robin_entrance != null and infrastructure_entrance != null
	if _runtime_entrances_ready:
		_sync_active_placement_occupancy()


func _ensure_entrance_for_map(
	room_map: RoomMapGridModule,
	entrance_name: String,
	target_map_id: StringName,
	grid_position: Vector2i
) -> EntranceFurniture:
	if room_map == null:
		return null
	var furniture_root := room_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return null

	var entrance := furniture_root.get_node_or_null(entrance_name) as EntranceFurniture
	if entrance == null:
		entrance = _instantiate_entrance()
		if entrance == null:
			return null
		entrance.name = entrance_name
		furniture_root.add_child(entrance)

	_configure_entrance(entrance, room_map, target_map_id, grid_position)
	return entrance


func _instantiate_entrance() -> EntranceFurniture:
	var scene := _get_entrance_scene()
	if scene != null:
		var scene_instance := scene.instantiate() as EntranceFurniture
		if scene_instance != null:
			return scene_instance
	return EntranceFurniture.new()


func _configure_entrance(
	entrance: EntranceFurniture,
	room_map: RoomMapGridModule,
	target_map_id: StringName,
	grid_position: Vector2i
) -> void:
	if entrance == null or room_map == null:
		return
	var safe_footprint := Vector2i(maxi(entrance_footprint.x, 1), maxi(entrance_footprint.y, 1))
	var safe_grid_position := _clamp_grid_position(room_map, grid_position, safe_footprint)
	entrance.target_map_id = target_map_id
	entrance.grid_footprint = safe_footprint
	entrance.built_in = true
	entrance.build_locked = true
	entrance.set_meta("furniture_id", entrance.furniture_id)
	entrance.set_meta("grid_position", safe_grid_position)
	entrance.set_meta("grid_footprint", safe_footprint)
	entrance.set_meta(BUILD_LOCK_META, true)
	entrance.global_position = room_map.grid_to_world_area_center(safe_grid_position, safe_footprint)
	if entrance.has_method("set_grid_cell_size"):
		entrance.call("set_grid_cell_size", room_map.get_cell_size())
	else:
		entrance.set("cell_size", room_map.get_cell_size())
		entrance.queue_redraw()


func _sync_entrance_layouts() -> void:
	_sync_entrance_layout(_robin_room_map, "RobinRoomEntrance", robin_room_entrance_grid_position)
	_sync_entrance_layout(_infrastructure_room_map, "InfrastructureRoomEntrance", infrastructure_room_entrance_grid_position)


func _sync_entrance_layout(room_map: RoomMapGridModule, entrance_name: String, grid_position: Vector2i) -> void:
	if room_map == null:
		return
	var furniture_root := room_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return
	var entrance := furniture_root.get_node_or_null(entrance_name) as EntranceFurniture
	if entrance == null:
		return
	_configure_entrance(entrance, room_map, entrance.target_map_id, grid_position)


func _sync_active_placement_occupancy() -> void:
	if _furniture_placement_module == null:
		return
	if _furniture_placement_module.has_method("sync_occupied_cells_from_furniture_root"):
		_furniture_placement_module.call("sync_occupied_cells_from_furniture_root")


func _clamp_grid_position(room_map: RoomMapGridModule, grid_position: Vector2i, footprint: Vector2i) -> Vector2i:
	if room_map == null:
		return grid_position
	var grid_size := room_map.get_grid_size()
	var max_x := maxi(grid_size.x - footprint.x, 0)
	var max_y := maxi(grid_size.y - footprint.y, 0)
	return Vector2i(clampi(grid_position.x, 0, max_x), clampi(grid_position.y, 0, max_y))


func _get_entrance_scene() -> PackedScene:
	if _entrance_scene != null:
		return _entrance_scene
	if entrance_scene_path.is_empty():
		return null
	if not ResourceLoader.exists(entrance_scene_path):
		return null
	_entrance_scene = load(entrance_scene_path) as PackedScene
	return _entrance_scene


func _resolve_refs() -> void:
	if _robin_room_map == null and not robin_room_map_path.is_empty():
		_robin_room_map = get_node_or_null(robin_room_map_path) as RoomMapGridModule
	if _infrastructure_room_map == null and not infrastructure_room_map_path.is_empty():
		_infrastructure_room_map = get_node_or_null(infrastructure_room_map_path) as RoomMapGridModule
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path) as FurniturePlacementModule
