extends RefCounted
class_name AICharacterActionContext

var actor: Node
var body: CharacterBody2D
var action_runner: AICharacterActionRunner


func bind_actor(p_actor: Node, p_action_runner: AICharacterActionRunner = null) -> void:
	actor = p_actor
	body = p_actor as CharacterBody2D
	action_runner = p_action_runner


func clear() -> void:
	actor = null
	body = null
	action_runner = null


func is_valid() -> bool:
	return actor != null and is_instance_valid(actor)


func get_actor_name() -> String:
	if not is_valid():
		return ""
	return actor.name


func get_actor_global_position() -> Vector2:
	var node_2d := actor as Node2D
	if node_2d == null:
		return Vector2.ZERO
	return node_2d.global_position


func get_actor_node(path: NodePath) -> Node:
	if not is_valid() or path.is_empty():
		return null
	return actor.get_node_or_null(path)


func get_needs_module() -> Node:
	if not is_valid() or not actor.has_method("get_needs_module"):
		return null
	return actor.call("get_needs_module") as Node


func get_mood_module() -> Node:
	if not is_valid() or not actor.has_method("get_mood_module"):
		return null
	return actor.call("get_mood_module") as Node


func get_need_planner() -> Node:
	if not is_valid() or not actor.has_method("get_need_planner"):
		return null
	return actor.call("get_need_planner") as Node


func get_inventory_module() -> Node:
	if not is_valid() or not actor.has_method("get_inventory_module"):
		return null
	return actor.call("get_inventory_module") as Node


func get_actor_grid_footprint(default_footprint: Vector2i = Vector2i(2, 4)) -> Vector2i:
	if not is_valid() or not actor.has_method("get_actor_grid_footprint"):
		return default_footprint
	var value: Variant = actor.call("get_actor_grid_footprint")
	if value is Vector2i:
		return value
	return default_footprint


func apply_movement_result(result: AICharacterActionResult) -> void:
	if result == null or not result.owns_movement or body == null:
		return
	body.velocity = result.velocity
	if result.velocity.length_squared() > 0.0:
		body.move_and_slide()
