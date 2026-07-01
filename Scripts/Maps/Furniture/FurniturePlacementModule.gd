extends Node
class_name FurniturePlacementModule

const BUILD_LOCK_META := &"build_locked_by_sleep"

@export var room_map_path: NodePath
@export var furniture_root_path: NodePath

var _room_map: RoomMapGridModule
var _furniture_root: Node2D
var _occupied_cells: Dictionary = {}


func _ready() -> void:
	_resolve_refs()
	sync_occupied_cells_from_furniture_root()


func set_room_map_path(next_room_map_path: NodePath) -> void:
	if room_map_path == next_room_map_path:
		_resolve_refs()
		return
	room_map_path = next_room_map_path
	_room_map = null
	_occupied_cells.clear()
	_resolve_refs()
	sync_occupied_cells_from_furniture_root()


func set_furniture_root_path(next_furniture_root_path: NodePath) -> void:
	if furniture_root_path == next_furniture_root_path:
		_resolve_refs()
		sync_occupied_cells_from_furniture_root()
		return
	furniture_root_path = next_furniture_root_path
	_furniture_root = null
	_occupied_cells.clear()
	_resolve_refs()
	sync_occupied_cells_from_furniture_root()


func sync_occupied_cells_from_furniture_root() -> void:
	_resolve_refs()
	_occupied_cells.clear()
	if _furniture_root == null:
		return
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not furniture.has_meta("grid_position"):
			continue
		var grid_position: Vector2i = furniture.get_meta("grid_position", Vector2i.ZERO)
		var footprint := get_furniture_footprint(furniture, Vector2i(1, 1))
		if furniture.has_meta("grid_footprint"):
			footprint = furniture.get_meta("grid_footprint", footprint)
		_register_furniture_cells(furniture, grid_position, footprint)


func can_place_at(grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> bool:
	_resolve_refs()
	if _room_map == null:
		return false
	if not _room_map.is_grid_area_inside(grid_position, footprint):
		return false

	for cell in _get_cells_in_footprint(grid_position, footprint):
		if _occupied_cells.has(_grid_key(cell)):
			return false

	return true


func place_furniture_scene(
	furniture_scene: PackedScene,
	grid_position: Vector2i,
	footprint: Vector2i = Vector2i(1, 1),
	furniture_id: StringName = &""
) -> Node2D:
	_resolve_refs()
	if furniture_scene == null or _room_map == null or _furniture_root == null:
		return null
	if not can_place_at(grid_position, footprint):
		return null

	var instance := furniture_scene.instantiate()
	var furniture := instance as Node2D
	if furniture == null:
		instance.queue_free()
		return null

	_furniture_root.add_child(furniture)
	_register_furniture(furniture, grid_position, footprint, furniture_id)
	return furniture


func place_furniture_scene_auto(
	furniture_scene: PackedScene,
	grid_position: Vector2i,
	furniture_id: StringName = &""
) -> Node2D:
	_resolve_refs()
	if furniture_scene == null or _room_map == null or _furniture_root == null:
		return null

	var instance := furniture_scene.instantiate()
	var furniture := instance as Node2D
	if furniture == null:
		instance.queue_free()
		return null

	var footprint := get_furniture_footprint(furniture, Vector2i(1, 1))
	if not can_place_at(grid_position, footprint):
		furniture.queue_free()
		return null

	_furniture_root.add_child(furniture)
	_register_furniture(furniture, grid_position, footprint, furniture_id)
	return furniture


func place_existing_furniture(
	furniture: Node2D,
	grid_position: Vector2i,
	footprint: Vector2i = Vector2i(1, 1),
	furniture_id: StringName = &""
) -> bool:
	_resolve_refs()
	if furniture == null or _room_map == null:
		return false
	if not can_place_at(grid_position, footprint):
		return false

	if _furniture_root != null and furniture.get_parent() == null:
		_furniture_root.add_child(furniture)

	_register_furniture(furniture, grid_position, footprint, furniture_id)
	return true


func place_existing_furniture_auto(
	furniture: Node2D,
	grid_position: Vector2i,
	furniture_id: StringName = &""
) -> bool:
	var footprint := get_furniture_footprint(furniture, Vector2i(1, 1))
	return place_existing_furniture(furniture, grid_position, footprint, furniture_id)


func move_furniture_to(furniture: Node2D, grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> bool:
	if furniture == null:
		return false
	if not can_modify_furniture(furniture):
		return false

	var old_grid_position: Vector2i = furniture.get_meta("grid_position", Vector2i.ZERO)
	var old_footprint: Vector2i = furniture.get_meta("grid_footprint", Vector2i(1, 1))
	var furniture_id: StringName = get_furniture_id(furniture)

	_unregister_furniture(furniture)
	if not can_place_at(grid_position, footprint):
		_register_furniture(furniture, old_grid_position, old_footprint, furniture_id)
		return false

	_register_furniture(furniture, grid_position, footprint, furniture_id)
	return true


func remove_furniture_at(grid_position: Vector2i) -> bool:
	var furniture := get_furniture_at(grid_position)
	if furniture == null:
		return false
	if not can_modify_furniture(furniture):
		return false

	_unregister_furniture(furniture)
	furniture.queue_free()
	return true


func take_furniture_at(grid_position: Vector2i) -> Node2D:
	var furniture := get_furniture_at(grid_position)
	if furniture == null:
		return null
	if not can_modify_furniture(furniture):
		return null
	_unregister_furniture(furniture)
	return furniture


func get_furniture_at(grid_position: Vector2i) -> Node2D:
	var key := _grid_key(grid_position)
	if not _occupied_cells.has(key):
		return null
	return _occupied_cells[key] as Node2D


func get_furniture_footprint(furniture: Node2D, fallback_footprint: Vector2i = Vector2i(1, 1)) -> Vector2i:
	return _get_furniture_footprint(furniture, fallback_footprint)


func get_furniture_id(furniture: Node2D) -> StringName:
	if furniture == null:
		return &""
	return furniture.get_meta("furniture_id", &"") as StringName


func can_modify_furniture(furniture: Node2D) -> bool:
	return not is_furniture_build_locked(furniture)


func is_furniture_build_locked(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("is_build_locked") and furniture.call("is_build_locked") == true:
		return true
	if furniture.has_meta(BUILD_LOCK_META):
		return bool(furniture.get_meta(BUILD_LOCK_META, false))
	return false


func get_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _room_map


func get_furniture_root() -> Node2D:
	_resolve_refs()
	return _furniture_root


func sync_furniture_to_room_grid(furniture: Node2D) -> void:
	_resolve_refs()
	if furniture == null or _room_map == null:
		return

	var room_cell_size := _room_map.get_cell_size()
	if furniture.has_method("set_grid_cell_size"):
		furniture.call("set_grid_cell_size", room_cell_size)
		return

	if _has_property(furniture, &"cell_size"):
		furniture.set("cell_size", room_cell_size)
		furniture.queue_redraw()


func clear_furniture() -> void:
	for furniture in _get_unique_furniture_nodes():
		if furniture != null:
			furniture.queue_free()
	_occupied_cells.clear()


func _register_furniture(
	furniture: Node2D,
	grid_position: Vector2i,
	footprint: Vector2i = Vector2i(1, 1),
	furniture_id: StringName = &""
) -> void:
	_resolve_refs()
	if furniture == null or _room_map == null:
		return

	sync_furniture_to_room_grid(furniture)
	furniture.global_position = _room_map.grid_to_world_area_center(grid_position, footprint)
	furniture.set_meta("grid_position", grid_position)
	furniture.set_meta("grid_footprint", footprint)
	if furniture_id != &"":
		furniture.set_meta("furniture_id", furniture_id)

	_register_furniture_cells(furniture, grid_position, footprint)


func _register_furniture_cells(
	furniture: Node2D,
	grid_position: Vector2i,
	footprint: Vector2i = Vector2i(1, 1)
) -> void:
	for cell in _get_cells_in_footprint(grid_position, footprint):
		_occupied_cells[_grid_key(cell)] = furniture


func _unregister_furniture(furniture: Node2D) -> void:
	for key in _occupied_cells.keys():
		if _occupied_cells[key] == furniture:
			_occupied_cells.erase(key)


func _get_unique_furniture_nodes() -> Array[Node2D]:
	var unique: Array[Node2D] = []
	for furniture in _occupied_cells.values():
		var node := furniture as Node2D
		if node != null and not unique.has(node):
			unique.append(node)
	return unique


func _get_cells_in_footprint(grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var safe_footprint := Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	for y in range(safe_footprint.y):
		for x in range(safe_footprint.x):
			cells.append(grid_position + Vector2i(x, y))
	return cells


func _get_furniture_footprint(furniture: Node2D, fallback_footprint: Vector2i = Vector2i(1, 1)) -> Vector2i:
	if furniture == null:
		return fallback_footprint
	if furniture.has_method("get_grid_footprint"):
		var method_footprint: Vector2i = furniture.call("get_grid_footprint")
		return Vector2i(maxi(method_footprint.x, 1), maxi(method_footprint.y, 1))
	if furniture.has_meta("grid_footprint"):
		var meta_footprint: Vector2i = furniture.get_meta("grid_footprint", fallback_footprint)
		return Vector2i(maxi(meta_footprint.x, 1), maxi(meta_footprint.y, 1))
	return Vector2i(maxi(fallback_footprint.x, 1), maxi(fallback_footprint.y, 1))


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule

	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path) as Node2D
