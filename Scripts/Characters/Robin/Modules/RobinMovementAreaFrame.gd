extends Control
class_name RobinMovementAreaFrame

@export var actor_path: NodePath = NodePath("..")
@export var raw_modulate_color: Color = Color(1.0, 2.8, 2.8, 1.0)
@export var outer_glow_width: float = 24.0
@export var middle_glow_width: float = 12.0
@export var core_line_width: float = 4.0

var _actor: RobinWanderActor


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	self_modulate = raw_modulate_color
	_actor = get_node_or_null(actor_path) as RobinWanderActor
	_sync_to_viewport()
	queue_redraw()


func _process(_delta: float) -> void:
	if _actor == null:
		_actor = get_node_or_null(actor_path) as RobinWanderActor
	_sync_to_viewport()
	queue_redraw()


func _draw() -> void:
	if _actor == null:
		return

	var area := _actor.get_movement_area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var local_area := Rect2(area.position - global_position, area.size)
	var outer_color := Color(0.0, 1.4, 1.4, 0.20)
	var middle_color := Color(0.0, 2.2, 2.2, 0.48)
	var core_color := Color(0.85, 4.0, 4.0, 1.0)

	draw_rect(local_area, outer_color, false, outer_glow_width)
	draw_rect(local_area, middle_color, false, middle_glow_width)
	draw_rect(local_area, core_color, false, core_line_width)


func _sync_to_viewport() -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	global_position = viewport_rect.position
	size = viewport_rect.size
