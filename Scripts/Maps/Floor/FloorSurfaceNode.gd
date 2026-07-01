extends Node2D
class_name FloorSurfaceNode

@export var display_name: String = "角丸フロアパネル"
@export var floor_id: StringName = &"floor_001"
@export var grid_footprint: Vector2i = Vector2i(15, 15)
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var texture_path: String = "res://Assets/Maps/Furniture/Floor/Floor_001.png"
@export var use_texture_when_available: bool = true
@export var preserve_texture_aspect: bool = false
@export var texture_fill_ratio: float = 1.0
@export var fallback_base_color: Color = Color(0.10, 0.13, 0.16, 0.96)
@export var fallback_inner_color: Color = Color(0.16, 0.20, 0.24, 0.96)
@export var fallback_border_color: Color = Color(0.0, 1.8, 2.0, 0.72)
@export var fallback_inner_border_color: Color = Color(0.45, 0.58, 0.68, 0.55)
@export var fallback_border_width: int = 2
@export var fallback_corner_radius: int = 14

var _texture: Texture2D
var _loaded_texture_path: String = ""


func _ready() -> void:
	z_as_relative = true
	_load_texture_if_needed()
	queue_redraw()


func _draw() -> void:
	var floor_size := get_pixel_size()
	if floor_size.x <= 0.0 or floor_size.y <= 0.0:
		return

	var rect := Rect2(-floor_size * 0.5, floor_size)
	if _should_use_texture():
		_draw_texture_floor(rect)
		return

	_draw_fallback_floor(rect)


func get_grid_footprint() -> Vector2i:
	return Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))


func get_pixel_size() -> Vector2:
	var safe_footprint := get_grid_footprint()
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	return Vector2(float(safe_footprint.x), float(safe_footprint.y)) * safe_cell_size


func set_grid_cell_size(next_cell_size: Vector2) -> void:
	cell_size = Vector2(maxf(next_cell_size.x, 1.0), maxf(next_cell_size.y, 1.0))
	queue_redraw()


func set_grid_footprint(next_grid_footprint: Vector2i) -> void:
	grid_footprint = Vector2i(maxi(next_grid_footprint.x, 1), maxi(next_grid_footprint.y, 1))
	queue_redraw()


func set_texture_path(next_texture_path: String) -> void:
	if texture_path == next_texture_path:
		return
	texture_path = next_texture_path
	_texture = null
	_loaded_texture_path = ""
	_load_texture_if_needed()
	queue_redraw()


func _should_use_texture() -> bool:
	_load_texture_if_needed()
	return use_texture_when_available and _texture != null


func _load_texture_if_needed() -> void:
	if _loaded_texture_path == texture_path:
		return
	_loaded_texture_path = texture_path
	_texture = null
	if texture_path.is_empty():
		return
	if not ResourceLoader.exists(texture_path):
		return
	_texture = load(texture_path) as Texture2D


func _draw_texture_floor(rect: Rect2) -> void:
	if _texture == null:
		return
	if preserve_texture_aspect:
		var texture_size := Vector2(float(_texture.get_width()), float(_texture.get_height()))
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return
		var target_size := rect.size * clampf(texture_fill_ratio, 0.1, 1.0)
		var fit_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		var draw_size := texture_size * fit_scale
		var texture_rect := Rect2(-draw_size * 0.5, draw_size)
		draw_texture_rect(_texture, texture_rect, false, Color.WHITE)
		return

	draw_texture_rect(_texture, rect, false, Color.WHITE)


func _draw_fallback_floor(rect: Rect2) -> void:
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = fallback_base_color
	outer_style.border_color = fallback_border_color
	outer_style.set_border_width_all(maxi(fallback_border_width, 0))
	outer_style.set_corner_radius_all(maxi(fallback_corner_radius, 0))
	draw_style_box(outer_style, rect)

	var inner_margin := maxf(float(fallback_border_width) * 4.0, 8.0)
	var inner_rect := rect.grow(-inner_margin)
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return

	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = fallback_inner_color
	inner_style.border_color = fallback_inner_border_color
	inner_style.set_border_width_all(1)
	inner_style.set_corner_radius_all(maxi(fallback_corner_radius - 4, 0))
	draw_style_box(inner_style, inner_rect)
