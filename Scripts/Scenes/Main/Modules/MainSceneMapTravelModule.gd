extends Node
class_name MainSceneMapTravelModule

const MAP_ID_ROBIN_ROOM: StringName = &"robin_room"
const MAP_ID_INFRASTRUCTURE_ROOM: StringName = &"infrastructure_room"

@export var default_map_id: StringName = MAP_ID_ROBIN_ROOM
@export var robin_room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var infrastructure_room_map_path: NodePath = NodePath("../InfrastructureRoomMap")
@export var robin_path: NodePath = NodePath("../Robin")
@export var to_infrastructure_button_path: NodePath = NodePath("../CanvasLayer/MainSceneTravelButtons/ToInfrastructureRoomButton")
@export var to_robin_room_button_path: NodePath = NodePath("../CanvasLayer/MainSceneTravelButtons/ToRobinRoomButton")
@export var debug_label_path: NodePath = NodePath("../CanvasLayer/DebugLabel")
@export var build_mode_controller_path: NodePath = NodePath("../BuildModeController")
@export var build_grid_overlay_path: NodePath = NodePath("../BuildGridHighlightOverlay")
@export var build_preview_path: NodePath = NodePath("../BuildFurniturePlacementPreview")
@export var floor_placement_module_path: NodePath = NodePath("../FloorPlacementModule")
@export var move_robin_to_map_center_on_travel: bool = true

var _robin_room_map: RoomMapGridModule
var _infrastructure_room_map: RoomMapGridModule
var _robin: Node2D
var _to_infrastructure_button: Button
var _to_robin_room_button: Button
var _debug_label: Label
var _active_map_id: StringName = &""


func _ready() -> void:
	_resolve_static_refs()
	_connect_buttons()
	set_active_map(default_map_id, true)
	set_process(true)


func _process(_delta: float) -> void:
	_resolve_static_refs()
	_connect_buttons()
	_sync_runtime_build_nodes()


func travel_to_infrastructure_room() -> void:
	set_active_map(MAP_ID_INFRASTRUCTURE_ROOM)


func travel_to_robin_room() -> void:
	set_active_map(MAP_ID_ROBIN_ROOM)


func get_active_map_id() -> StringName:
	return _active_map_id


func get_active_map() -> RoomMapGridModule:
	return _get_map_for_id(_active_map_id)


func set_active_map(map_id: StringName, force: bool = false) -> void:
	_resolve_static_refs()
	var next_map := _get_map_for_id(map_id)
	if next_map == null:
		return
	if not force and _active_map_id == map_id:
		_sync_runtime_build_nodes()
		return

	_active_map_id = map_id
	_apply_map_visibility()
	_sync_robin_to_active_map()
	_sync_runtime_build_nodes()
	_sync_travel_buttons()
	_update_debug_label()


func _get_map_for_id(map_id: StringName) -> RoomMapGridModule:
	if map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return _infrastructure_room_map
	return _robin_room_map


func _get_active_runtime_room_map_path() -> NodePath:
	if _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return infrastructure_room_map_path
	return robin_room_map_path


func _get_active_floor_root_path() -> NodePath:
	if _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return NodePath("../InfrastructureRoomMap/FloorRoot")
	return NodePath("../RobinRoomMap/FloorRoot")


func _get_active_wander_provider_path() -> NodePath:
	if _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return NodePath("../InfrastructureRoomMap")
	return NodePath("../RobinRoomMap")


func _get_active_furniture_root_path_for_robin_modules() -> NodePath:
	if _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return NodePath("../../InfrastructureRoomMap/FurnitureRoot")
	return NodePath("../../RobinRoomMap/FurnitureRoot")


func _apply_map_visibility() -> void:
	if _robin_room_map != null:
		_robin_room_map.visible = _active_map_id == MAP_ID_ROBIN_ROOM
	if _infrastructure_room_map != null:
		_infrastructure_room_map.visible = _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM


func _sync_robin_to_active_map() -> void:
	if _robin == null:
		return

	var wander_module := _robin.get_node_or_null("RobinRandomWanderModule")
	if wander_module != null:
		var provider_path := _get_active_wander_provider_path()
		if wander_module.has_method("set_movement_area_provider_path"):
			wander_module.call("set_movement_area_provider_path", provider_path)
		else:
			wander_module.set("movement_area_provider_path", provider_path)
			wander_module.set("_movement_area_provider", null)

	var rest_module := _robin.get_node_or_null("AICharacterSleepBehaviorModule")
	if rest_module != null:
		var furniture_root_path := _get_active_furniture_root_path_for_robin_modules()
		rest_module.set("furniture_root_path", furniture_root_path)
		rest_module.set("_furniture_root", null)
		rest_module.set("_target_bedding", null)
		if rest_module.has_method("_stop_sleeping"):
			rest_module.call("_stop_sleeping")

	if move_robin_to_map_center_on_travel:
		_move_robin_to_active_map_center()


func _move_robin_to_active_map_center() -> void:
	var active_map := get_active_map()
	if _robin == null or active_map == null:
		return
	if not active_map.has_method("get_grid_rect"):
		return
	var grid_rect: Rect2 = active_map.get_grid_rect()
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return
	_robin.global_position = grid_rect.position + grid_rect.size * 0.5


func _sync_runtime_build_nodes() -> void:
	var active_map_path := _get_active_runtime_room_map_path()
	var active_map := get_active_map()

	var controller := get_node_or_null(build_mode_controller_path)
	if controller != null:
		if controller.has_method("set_room_map_path"):
			controller.call("set_room_map_path", active_map_path)
		else:
			controller.set("room_map_path", active_map_path)
			controller.set("_room_map", null)
		if active_map != null and active_map.has_method("is_buildable") and not active_map.is_buildable():
			controller.call("set_build_mode_enabled", false)

	var overlay := get_node_or_null(build_grid_overlay_path)
	if overlay != null:
		if overlay.has_method("set_room_map_path"):
			overlay.call("set_room_map_path", active_map_path)
		else:
			overlay.set("room_map_path", active_map_path)
			overlay.set("_room_map", null)

	var preview := get_node_or_null(build_preview_path)
	if preview != null:
		if preview.has_method("set_room_map_path"):
			preview.call("set_room_map_path", active_map_path)
		else:
			preview.set("room_map_path", active_map_path)
			preview.set("_room_map", null)

	var floor_placement := get_node_or_null(floor_placement_module_path)
	if floor_placement != null:
		if floor_placement.has_method("set_room_map_path"):
			floor_placement.call("set_room_map_path", active_map_path)
		else:
			floor_placement.set("room_map_path", active_map_path)
			floor_placement.set("_room_map", null)
		var active_floor_root_path := _get_active_floor_root_path()
		if floor_placement.has_method("set_floor_root_path"):
			floor_placement.call("set_floor_root_path", active_floor_root_path)
		else:
			floor_placement.set("floor_root_path", active_floor_root_path)
			floor_placement.set("_floor_root", null)


func _sync_travel_buttons() -> void:
	if _to_infrastructure_button != null:
		_to_infrastructure_button.visible = _active_map_id == MAP_ID_ROBIN_ROOM
		_to_infrastructure_button.disabled = _active_map_id != MAP_ID_ROBIN_ROOM
	if _to_robin_room_button != null:
		_to_robin_room_button.visible = _active_map_id == MAP_ID_INFRASTRUCTURE_ROOM
		_to_robin_room_button.disabled = _active_map_id != MAP_ID_INFRASTRUCTURE_ROOM


func _update_debug_label() -> void:
	if _debug_label == null:
		return
	var active_map := get_active_map()
	if active_map == null:
		return
	var grid_size := active_map.get_grid_size()
	_debug_label.text = "%s 起動中 / Grid %d x %d" % [active_map.map_display_name, grid_size.x, grid_size.y]


func _connect_buttons() -> void:
	if _to_infrastructure_button != null:
		var to_infrastructure_callable := Callable(self, "travel_to_infrastructure_room")
		if not _to_infrastructure_button.pressed.is_connected(to_infrastructure_callable):
			_to_infrastructure_button.pressed.connect(to_infrastructure_callable)
	if _to_robin_room_button != null:
		var to_robin_room_callable := Callable(self, "travel_to_robin_room")
		if not _to_robin_room_button.pressed.is_connected(to_robin_room_callable):
			_to_robin_room_button.pressed.connect(to_robin_room_callable)


func _resolve_static_refs() -> void:
	if _robin_room_map == null and not robin_room_map_path.is_empty():
		_robin_room_map = get_node_or_null(robin_room_map_path) as RoomMapGridModule
	if _infrastructure_room_map == null and not infrastructure_room_map_path.is_empty():
		_infrastructure_room_map = get_node_or_null(infrastructure_room_map_path) as RoomMapGridModule
	if _robin == null and not robin_path.is_empty():
		_robin = get_node_or_null(robin_path) as Node2D
	if _to_infrastructure_button == null and not to_infrastructure_button_path.is_empty():
		_to_infrastructure_button = get_node_or_null(to_infrastructure_button_path) as Button
	if _to_robin_room_button == null and not to_robin_room_button_path.is_empty():
		_to_robin_room_button = get_node_or_null(to_robin_room_button_path) as Button
	if _debug_label == null and not debug_label_path.is_empty():
		_debug_label = get_node_or_null(debug_label_path) as Label
