extends RobinRandomWanderModule
class_name AICharacterRandomWanderModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

@export var ai_actor_group_name: StringName = &"ai_character_actor"
@export var use_shared_move_slot: bool = true
@export var avoid_ai_character_grids: bool = true


func setup(body: Node2D) -> void:
	super.setup(body)
	if _body != null and not _body.is_in_group(ai_actor_group_name):
		_body.add_to_group(ai_actor_group_name)


func get_velocity(delta: float) -> Vector2:
	if _body == null:
		return Vector2.ZERO
	if use_shared_move_slot and not _can_step_now():
		_start_idle()
		return Vector2.ZERO
	var next_velocity := super.get_velocity(delta)
	if use_shared_move_slot and not is_moving():
		MoveSlot.release_move(_body)
	return next_velocity


func _can_step_now() -> bool:
	if _body == null:
		return false
	if MoveSlot.is_other_actor_moving(_body, ai_actor_group_name):
		return false
	return MoveSlot.request_move(_body)
