extends Node2D
class_name KitchenModuleFurniture

@export var display_name: String = "キッチンモジュール"
@export var furniture_id: StringName = &"kitchen_module"
@export var grid_footprint: Vector2i = Vector2i(4, 2)
@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var use_sprite_when_available: bool = true
@export var preserve_sprite_aspect: bool = true
@export var sprite_fill_ratio: float = 1.0
@export var base_color: Color = Color(0.08, 0.09, 0.10, 1.0)
@export var edge_color: Color = Color(0.05, 0.95, 1.0, 0.92)
@export var panel_color: Color = Color(0.14, 0.16, 0.18, 1.0)
@export var dark_panel_color: Color = Color(0.03, 0.04, 0.05, 1.0)
@export var fill_grid_preview: bool = false

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
	var inset_rect := rect.grow(-5.0)
	var sink_rect := Rect2(rect.position + Vector2(14.0, 18.0), Vector2(66.0, 60.0))
	var basin_rect := Rect2(sink_rect.position + Vector2(12.0, 13.0), Vector2(42.0, 32.0))
	var prep_rect := Rect2(rect.position + Vector2(94.0, 18.0), Vector2(44.0, 60.0))
	var cooker_rect := Rect2(rect.position + Vector2(150.0, 18.0), Vector2(30.0, 60.0))

	draw_rect(rect, base_color, true)
	draw_rect(rect, edge_color, false, 2.0)
	draw_rect(inset_rect, Color(edge_color.r, edge_color.g, edge_color.b, 0.18), false, 1.0)

	_draw_panel(sink_rect)
	_draw_panel(prep_rect)
	_draw_panel(cooker_rect, dark_panel_color)

	draw_rect(basin_rect, Color(0.10, 0.13, 0.14, 1.0), true)
	draw_rect(basin_rect, edge_color, false, 2.0)
	draw_circle(basin_rect.get_center() + Vector2(0.0, -2.0), 5.0, dark_panel_color)
	draw_arc(basin_rect.get_center() + Vector2(0.0, -2.0), 6.0, 0.0, TAU, 24, Color(0.36, 0.43, 0.47, 1.0), 1.2)

	_draw_faucet(basin_rect)
	_draw_prep_grooves(prep_rect)
	_draw_cooker(cooker_rect)

	if fill_grid_preview:
		_draw_footprint_guide(rect)


func get_grid_footprint() -> Vector2i:
	return grid_footprint


func get_pixel_size() -> Vector2:
	var safe_footprint := Vector2i(maxi(grid_footprint.x, 1), maxi(grid_footprint.y, 1))
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	return Vector2(float(safe_footprint.x), float(safe_footprint.y)) * safe_cell_size


func _draw_panel(rect: Rect2, color: Color = panel_color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.80), false, 2.0)


func _draw_faucet(basin_rect: Rect2) -> void:
	var base_center := basin_rect.position + Vector2(24.0, -5.0)
	var spout_tip := basin_rect.position + Vector2(38.0, 5.0)
	var pipe_color := Color(0.52, 0.58, 0.62, 1.0)
	var pipe_dark := Color(0.12, 0.14, 0.16, 1.0)

	draw_circle(base_center, 7.0, pipe_color)
	draw_arc(base_center + Vector2(8.0, 4.0), 14.0, PI, TAU, 18, pipe_dark, 6.0)
	draw_arc(base_center + Vector2(8.0, 4.0), 14.0, PI, TAU, 18, pipe_color, 3.0)
	draw_line(base_center + Vector2(8.0, -10.0), spout_tip, pipe_color, 5.0)
	draw_circle(spout_tip, 3.0, edge_color)
	draw_rect(Rect2(base_center + Vector2(-15.0, -3.0), Vector2(10.0, 6.0)), pipe_color, true)


func _draw_prep_grooves(prep_rect: Rect2) -> void:
	for index in range(4):
		var y := prep_rect.position.y + 14.0 + float(index) * 11.0
		draw_line(
			Vector2(prep_rect.position.x + 10.0, y),
			Vector2(prep_rect.end.x - 10.0, y),
			Color(0.33, 0.39, 0.42, 1.0),
			2.0
		)


func _draw_cooker(cooker_rect: Rect2) -> void:
	for y_offset in [18.0, 42.0]:
		var center := cooker_rect.position + Vector2(cooker_rect.size.x * 0.5, y_offset)
		draw_arc(center, 9.0, 0.0, TAU, 32, edge_color, 2.0)
		draw_arc(center, 5.0, 0.0, TAU, 32, edge_color, 1.0)

	for index in range(3):
		draw_circle(cooker_rect.position + Vector2(7.0 + float(index) * 7.0, 54.0), 2.2, edge_color)


func _fit_sprite_to_grid_size() -> void:
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
	var guide_color := Color(edge_color.r, edge_color.g, edge_color.b, 0.18)

	for x in range(1, safe_footprint.x):
		var draw_x := rect.position.x + float(x) * safe_cell_size.x
		draw_line(Vector2(draw_x, rect.position.y), Vector2(draw_x, rect.end.y), guide_color, 1.0)

	for y in range(1, safe_footprint.y):
		var draw_y := rect.position.y + float(y) * safe_cell_size.y
		draw_line(Vector2(rect.position.x, draw_y), Vector2(rect.end.x, draw_y), guide_color, 1.0)
