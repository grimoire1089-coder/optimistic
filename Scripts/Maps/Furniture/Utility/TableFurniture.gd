extends Node2D
class_name TableFurniture

@export var display_name: String = "テーブル"
@export var furniture_id: StringName = &"table"
@export var grid_footprint: Vector2i = Vector2i(4, 2)
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var use_sprite_when_available: bool = true
@export var preserve_sprite_aspect: bool = true
@export var sprite_fill_ratio: float = 1.0
@export var fallback_base_color: Color = Color(0.08, 0.09, 0.10, 1.0)
@export var fallback_edge_color: Color = Color(0.05, 0.95, 1.0, 0.92)
@export var fallback_inner_color: Color = Color(0.18, 0.20, 0.22, 1.0)

var _sprite: Sprite2D


func _ready() -> void:
	z_as_relative = true
	_resolve_sprite()
	_fit_sprite_to_grid_size()
	queue_redraw()


func _draw() -> void:
	if _should_use_sprite():
		return

	var furniture_size := get_pixel_size()
	var rect := Rect2(-furniture_size * 0.5, furniture_size)
	var inset_rect := rect.grow(-7.0)
	draw_rect(rect, fallback_base_color, true)
	draw_rect(rect, fallback_edge_color, false, 2.0)
	draw_rect(inset_rect, fallback_inner_color, true)
	draw_rect(inset_rect, Color(fallback_edge_color.r, fallback_edge_color.g, fallback_edge_color.b, 0.22), false, 1.5)


func get_grid_footprint() -> Vector2i:
	return grid_footprint


func get_pixel_size() -> Vector2:
	var safe_footprint := Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	return Vector2(float(safe_footprint.x), float(safe_footprint.y)) * safe_cell_size


func is_table() -> bool:
	return true


func set_grid_cell_size(next_cell_size: Vector2) -> void:
	var safe_cell_size := Vector2(maxf(next_cell_size.x, 1.0), maxf(next_cell_size.y, 1.0))
	if cell_size.is_equal_approx(safe_cell_size):
		return
	cell_size = safe_cell_size
	_fit_sprite_to_grid_size()
	queue_redraw()


func _fit_sprite_to_grid_size() -> void:
	_resolve_sprite()
	if _sprite == null or _sprite.texture == null:
		return

	_sprite.centered = true
	var texture_size := Vector2(float(_sprite.texture.get_width()), float(_sprite.texture.get_height()))
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var target_size := get_pixel_size() * clampf(sprite_fill_ratio, 0.1, 1.0)
	if preserve_sprite_aspect:
		var fit_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		_sprite.scale = Vector2(fit_scale, fit_scale)
	else:
		_sprite.scale = target_size / texture_size
	_sprite.position = Vector2.ZERO


func _should_use_sprite() -> bool:
	_resolve_sprite()
	return use_sprite_when_available and _sprite != null and _sprite.texture != null


func _resolve_sprite() -> void:
	if _sprite != null:
		return
	if sprite_path.is_empty():
		return
	_sprite = get_node_or_null(sprite_path) as Sprite2D
