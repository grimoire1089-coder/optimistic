extends Control
class_name AIPositionDebugOverlay

@export var actor_node_names: PackedStringArray = ["Robin", "Zippy"]
@export var actor_group_name: StringName = &"ai_character_actor"
@export var origin_radius: float = 5.0
@export var cross_half_size: float = 14.0
@export var redraw_interval_seconds: float = 0.1

var _redraw_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(visible)


func set_debug_visible(debug_visible: bool) -> void:
	visible = debug_visible
	set_process(debug_visible)
	queue_redraw()


func _process(delta: float) -> void:
	_redraw_timer -= maxf(delta, 0.0)
	if _redraw_timer > 0.0:
		return
	_redraw_timer = maxf(redraw_interval_seconds, 0.05)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	for actor in _get_debug_actors():
		_draw_actor_position(actor)


func _get_debug_actors() -> Array[Node2D]:
	var actors: Array[Node2D] = []
	var seen := {}
	for actor_name in actor_node_names:
		var named_actor := _find_actor(String(actor_name))
		if named_actor == null:
			continue
		seen[named_actor.get_instance_id()] = true
		actors.append(named_actor)
	for candidate in get_tree().get_nodes_in_group(actor_group_name):
		var actor := candidate as Node2D
		if actor == null:
			continue
		var id := actor.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		actors.append(actor)
	return actors


func _find_actor(actor_name: String) -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var direct := scene.get_node_or_null(actor_name) as Node2D
	if direct != null:
		return direct
	return scene.find_child(actor_name, true, false) as Node2D


func _draw_actor_position(actor: Node2D) -> void:
	var origin := actor.global_position
	var color := _get_actor_color(actor.name)
	draw_circle(origin, origin_radius, color)
	draw_line(origin + Vector2(-cross_half_size, 0.0), origin + Vector2(cross_half_size, 0.0), color, 2.0)
	draw_line(origin + Vector2(0.0, -cross_half_size), origin + Vector2(0.0, cross_half_size), color, 2.0)
	_draw_sprite_bounds(actor, color)
	_draw_click_bounds(actor, Color(color.r, color.g, color.b, 0.55))


func _draw_sprite_bounds(actor: Node2D, color: Color) -> void:
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var rect := sprite.get_rect()
	var p0 := sprite.to_global(rect.position)
	var p1 := sprite.to_global(rect.position + Vector2(rect.size.x, 0.0))
	var p2 := sprite.to_global(rect.position + rect.size)
	var p3 := sprite.to_global(rect.position + Vector2(0.0, rect.size.y))
	draw_line(p0, p1, color, 1.0)
	draw_line(p1, p2, color, 1.0)
	draw_line(p2, p3, color, 1.0)
	draw_line(p3, p0, color, 1.0)


func _draw_click_bounds(actor: Node2D, color: Color) -> void:
	var shape_node := actor.get_node_or_null("ClickArea2D/ClickCollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var collision_shape_size := rect_shape.size * shape_node.global_scale.abs()
	var rect := Rect2(shape_node.global_position - collision_shape_size * 0.5, collision_shape_size)
	draw_rect(rect, color, false, 1.0)


func _get_actor_color(actor_name: String) -> Color:
	if actor_name == "Zippy":
		return Color(1.0, 0.35, 0.35, 0.9)
	if actor_name == "Robin":
		return Color(0.35, 0.85, 1.0, 0.9)
	return Color(0.85, 1.0, 0.55, 0.9)
