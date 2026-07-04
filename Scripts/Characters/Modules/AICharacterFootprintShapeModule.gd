extends Node
class_name AICharacterFootprintShapeModule

@export var shape_path: NodePath = NodePath("../CollisionShape2D")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var footprint_cells: Vector2i = Vector2i(2, 2)
@export var center_cell_offset: Vector2 = Vector2(0.0, 1.0)
@export var resolve_interval_seconds: float = 0.25

var _shape_node: CollisionShape2D
var _room_map: RoomMapGridModule
var _last_cell_size := Vector2(-1.0, -1.0)
var _resolve_timer := 0.0


func _ready() -> void:
	_refresh_shape()


func _process(delta: float) -> void:
	_resolve_timer -= maxf(delta, 0.0)
	if _resolve_timer > 0.0:
		return
	_resolve_timer = maxf(resolve_interval_seconds, 0.05)
	_refresh_shape()
	if _shape_node != null and _room_map != null:
		set_process(false)


func _refresh_shape() -> void:
	if _shape_node == null:
		_shape_node = get_node_or_null(shape_path) as CollisionShape2D
	if _room_map == null:
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _shape_node == null or _room_map == null:
		return

	var cell_size := _room_map.get_cell_size()
	if cell_size.is_equal_approx(_last_cell_size):
		return
	_last_cell_size = cell_size

	var safe_footprint := Vector2i(maxi(footprint_cells.x, 1), maxi(footprint_cells.y, 1))
	var rect_shape := _shape_node.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		_shape_node.shape = rect_shape
	rect_shape.size = Vector2(float(safe_footprint.x), float(safe_footprint.y)) * cell_size
	_shape_node.position = Vector2(center_cell_offset.x * cell_size.x, center_cell_offset.y * cell_size.y)
