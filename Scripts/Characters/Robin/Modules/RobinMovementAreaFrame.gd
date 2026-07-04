extends Control
class_name RobinMovementAreaFrame

@export var actor_path: NodePath = NodePath("..")
@export var raw_modulate_color: Color = Color(1.0, 2.8, 2.8, 1.0)
@export var outer_glow_width: float = 24.0
@export var middle_glow_width: float = 12.0
@export var core_line_width: float = 4.0
@export var update_interval_seconds: float = 0.25

var _actor: RobinWanderActor
var _last_viewport_rect := Rect2()
var _last_area := Rect2()
var _update_timer := 0.0


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	self_modulate = raw_modulate_color
	_actor = get_node_or_null(actor_path) as RobinWanderActor
	_sync_layout(true)


func _process(delta: float) -> void:
	_update_timer -= maxf(delta, 0.0)
	if _update_timer > 0.0:
		return
	_update_timer = maxf(update_interval_seconds, 0.05)
	if _actor == null:
		_actor = get_node_or_null(actor_path) as RobinWanderActor
	_sync_layout(false)


func _draw() -> void:
	if _actor == null:
		return

	var area := _actor.get_grid_movement_area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var local_area := Rect2(area.position - global_position, area.size)
	var outer_color := Color(0.0, 1.4, 1.4, 0.20)
	var middle_color := Color(0.0, 2.2, 2.2, 0.48)
	var core_color := Color(0.85, 4.0, 4.0, 1.0)

	_draw_outside_rect_stroke(local_area, outer_color, outer_glow_width)
	_draw_outside_rect_stroke(local_area, middle_color, middle_glow_width)
	draw_rect(local_area, core_color, false, core_line_width)


func _draw_outside_rect_stroke(base_rect: Rect2, color: Color, width: float) -> void:
	var source_width := maxf(width, 0.0)
	if source_width <= 0.0:
		return
	var stroke_width := source_width * 0.5
	draw_rect(base_rect.grow(stroke_width * 0.5), color, false, stroke_width)


func _sync_layout(force_redraw: bool) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	global_position = viewport_rect.position
	size = viewport_rect.size

	var area := Rect2()
	if _actor != null:
		area = _actor.get_grid_movement_area()

	if force_redraw or not viewport_rect.is_equal_approx(_last_viewport_rect) or not area.is_equal_approx(_last_area):
		_last_viewport_rect = viewport_rect
		_last_area = area
		queue_redraw()
