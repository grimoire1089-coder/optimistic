extends Node2D
class_name RobinMovementAreaFrame

@export var actor_path: NodePath = NodePath("..")
@export var neon_color: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var outer_glow_width: float = 18.0
@export var middle_glow_width: float = 10.0
@export var core_line_width: float = 4.0

var _actor: RobinWanderActor


func _ready() -> void:
	top_level = true
	z_index = 10
	_actor = get_node_or_null(actor_path) as RobinWanderActor
	queue_redraw()


func _process(_delta: float) -> void:
	if _actor == null:
		_actor = get_node_or_null(actor_path) as RobinWanderActor
	queue_redraw()


func _draw() -> void:
	if _actor == null:
		return

	var area := _actor.get_movement_area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var outer_color := neon_color
	outer_color.a = 0.14

	var middle_color := neon_color
	middle_color.a = 0.32

	var core_color := Color(0.85, 1.0, 1.0, 1.0)

	draw_rect(area, outer_color, false, outer_glow_width)
	draw_rect(area, middle_color, false, middle_glow_width)
	draw_rect(area, core_color, false, core_line_width)
