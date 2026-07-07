extends RefCounted
class_name AICharacterMovementCoordinator

static var _active_mover_ref: WeakRef


static func request_move(actor: Node) -> bool:
	if actor == null:
		return false
	var active_mover := get_active_mover()
	if active_mover == null or active_mover == actor:
		_active_mover_ref = weakref(actor)
		return true
	return false


static func release_move(actor: Node) -> void:
	if actor == null:
		return
	var active_mover := get_active_mover()
	if active_mover == actor:
		_active_mover_ref = null


static func can_move(actor: Node) -> bool:
	if actor == null:
		return false
	var active_mover := get_active_mover()
	return active_mover == null or active_mover == actor


static func get_active_mover() -> Node:
	if _active_mover_ref == null:
		return null
	var active_mover := _active_mover_ref.get_ref() as Node
	if active_mover == null or not is_instance_valid(active_mover):
		_active_mover_ref = null
		return null
	return active_mover


static func is_other_actor_moving(actor: Node, actor_group_name: StringName = &"ai_character_actor") -> bool:
	if actor == null or actor.get_tree() == null:
		return false
	for candidate in actor.get_tree().get_nodes_in_group(actor_group_name):
		if candidate == null or candidate == actor:
			continue
		if _is_actor_moving(candidate):
			return true
	return false


static func _is_actor_moving(actor: Node) -> bool:
	if actor == null:
		return false
	if actor.has_method("is_ai_character_moving"):
		return bool(actor.call("is_ai_character_moving"))
	if actor is CharacterBody2D:
		var body := actor as CharacterBody2D
		if body.velocity.length_squared() > 0.01:
			return true
	for child in actor.get_children():
		if child != null and child.has_method("is_moving") and bool(child.call("is_moving")):
			return true
	return false
