extends Node
class_name FurniturePlacementModule

@export var room_map_path: NodePath
@export var furniture_root_path: NodePath

var _room_map: RoomMapGridModule
var _furniture_root: Node2D
var _occupied_cells: Dictionary = {}


func _ready() -> void:
	_resolve_refs()


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


func move_furniture_to(furniture: Node2D, grid_position: Vector2i, footprint: Vector2i = Vector2i(1, 1)) -> bool:
	if furniture == null:
		return false

	_unregister_furniture(furniture)
	if not can_place_at(grid_position, footprint):
		var old_grid_position: Variant = furniture.get_meta("grid_position", Vector2i.ZERO)
		var old_footprint: Variant = furniture.get_meta("grid_footprint", Vector2i(1, 1))
		_register_furniture(furniture, old_grid_position as Vector2i, old_footprint as Vector2i, furniture.get_meta("furniture_id", &"") as StringName)
		return false

	_register_furniture(furniture, grid_position, footprint, furniture.get_meta("furniture_id", &"") as StringName)
	return true


func remove_furniture_at(grid_position: Vector2i) -> bool:
	var furniture := get_furniture_at(grid_position)
	if furniture == null:
		return false

	_unregister_furniture(furniture)
	furniture.queue_free()
	return true


func get_furniture_at(grid_position: Vector2i) -> Node2D:
	var key := _grid_key(grid_position)
	if not _occupied_cells.has(key):
		return null
	return _occupied_cells[key] as Node2D


func get_room_map() -> RoomMapGridModule:
	_resolve_refs()
	return _room_map


func get_furniture_root() -> Node2D:
	_resolve_refs()
	return _furniture_root


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

	furniture.global_position = _room_map.grid_to_world_cell_center(grid_position)
	furniture.set_meta("grid_position", grid_position)
	furniture.set_meta("grid_footprint", footprint)
	if furniture_id != &"":
		furniture.set_meta("furniture_id", furniture_id)

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


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule

	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path) as Node2D
