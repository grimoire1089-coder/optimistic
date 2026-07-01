extends Node2D
class_name EntranceFurniture

signal travel_requested(entrance: EntranceFurniture, target_map_id: StringName)

@export var display_name: String = "エントランス"
@export var furniture_id: StringName = &"entrance"
@export var target_map_id: StringName = &""
@export var grid_footprint: Vector2i = Vector2i(3, 1)
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var click_shape_path: NodePath = NodePath("ClickArea2D/CollisionShape2D")
@export var preserve_sprite_aspect: bool = true
@export var sprite_fill_ratio: float = 1.0
@export var built_in: bool = true
@export var build_locked: bool = true

var _sprite: Sprite2D
var _click_shape: CollisionShape2D


func _ready() -> void:
	z_as_relative = true
	_resolve_nodes()
	_configure_click_area()
	_fit_to_grid_size()


func get_grid_footprint() -> Vector2i:
	return grid_footprint


func get_pixel_size() -> Vector2:
	var safe_footprint := Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	return Vector2(float(safe_footprint.x), float(safe_footprint.y)) * safe_cell_size


func set_grid_cell_size(next_cell_size: Vector2) -> void:
	cell_size = Vector2(maxf(next_cell_size.x, 1.0), maxf(next_cell_size.y, 1.0))
	_fit_to_grid_size()


func set_target_map_id(next_target_map_id: StringName) -> void:
	target_map_id = next_target_map_id


func is_build_locked() -> bool:
	return built_in or build_locked


func _configure_click_area() -> void:
	var click_area := get_node_or_null("ClickArea2D") as Area2D
	if click_area == null:
		return
	click_area.input_pickable = true
	var callable := Callable(self, "_on_click_area_input_event")
	if not click_area.input_event.is_connected(callable):
		click_area.input_event.connect(callable)


func _on_click_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	travel_requested.emit(self, target_map_id)
	get_viewport().set_input_as_handled()


func _fit_to_grid_size() -> void:
	_resolve_nodes()
	_fit_sprite_to_grid_size()
	_fit_click_shape_to_grid_size()
	queue_redraw()


func _fit_sprite_to_grid_size() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.centered = true
	var texture_size := Vector2(float(_sprite.texture.get_width()), float(_sprite.texture.get_height()))
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var target_size := get_pixel_size() * clampf(sprite_fill_ratio, 0.1, 1.2)
	if preserve_sprite_aspect:
		var fit_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		_sprite.scale = Vector2(fit_scale, fit_scale)
	else:
		_sprite.scale = target_size / texture_size
	_sprite.position = Vector2.ZERO


func _fit_click_shape_to_grid_size() -> void:
	if _click_shape == null:
		return
	var rect_shape := _click_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		_click_shape.shape = rect_shape
	rect_shape.size = get_pixel_size()
	_click_shape.position = Vector2.ZERO


func _resolve_nodes() -> void:
	if _sprite == null and not sprite_path.is_empty():
		_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _click_shape == null and not click_shape_path.is_empty():
		_click_shape = get_node_or_null(click_shape_path) as CollisionShape2D
