extends Node2D
class_name SimpleMattressFurniture

@export var display_name: String = "シンプルマットレス"
@export var furniture_id: StringName = &"simple_mattress"
@export var grid_footprint: Vector2i = Vector2i(2, 4)
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var use_sprite_when_available: bool = true
@export var preserve_sprite_aspect: bool = true
@export var sprite_fill_ratio: float = 1.0
@export var base_color: Color = Color(0.86, 0.92, 0.98, 1.0)
@export var edge_color: Color = Color(0.28, 0.74, 0.92, 1.0)
@export var seam_color: Color = Color(0.50, 0.82, 0.95, 0.72)
@export var pillow_color: Color = Color(0.96, 0.98, 1.0, 1.0)
@export var fill_grid_preview: bool = true

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
	var inset_rect := rect.grow(-4.0)
	var pillow_rect := Rect2(
		inset_rect.position + Vector2(8.0, 8.0),
		Vector2(maxf(cell_size.x - 16.0, 4.0), maxf(inset_rect.size.y - 16.0, 4.0))
	)

	draw_rect(rect, base_color, true)
	draw_rect(rect, edge_color, false, 3.0)
	draw_rect(inset_rect, seam_color, false, 1.5)
	draw_rect(pillow_rect, pillow_color, true)
	draw_rect(pillow_rect, seam_color, false, 1.5)

	var center_line_x := pillow_rect.end.x + 8.0
	draw_line(
		Vector2(center_line_x, inset_rect.position.y + 6.0),
		Vector2(center_line_x, inset_rect.end.y - 6.0),
		seam_color,
		1.2
	)

	if fill_grid_preview:
		_draw_footprint_guide(rect)


func get_grid_footprint() -> Vector2i:
	return grid_footprint


func get_pixel_size() -> Vector2:
	var safe_footprint := Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	return Vector2(float(safe_footprint.x), float(safe_footprint.y)) * safe_cell_size


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


func _draw_footprint_guide(rect: Rect2) -> void:
	var safe_footprint := Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	var guide_color := Color(seam_color.r, seam_color.g, seam_color.b, 0.24)

	for x in range(1, safe_footprint.x):
		var draw_x := rect.position.x + float(x) * safe_cell_size.x
		draw_line(Vector2(draw_x, rect.position.y), Vector2(draw_x, rect.end.y), guide_color, 1.0)

	for y in range(1, safe_footprint.y):
		var draw_y := rect.position.y + float(y) * safe_cell_size.y
		draw_line(Vector2(rect.position.x, draw_y), Vector2(rect.end.x, draw_y), guide_color, 1.0)
