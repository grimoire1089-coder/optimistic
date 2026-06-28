extends CharacterBody2D
class_name RobinWanderActor

@export var start_at_movement_area_center: bool = true

@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator


func _ready() -> void:
	wander_module.setup(self)
	if start_at_movement_area_center:
		global_position = wander_module.get_movement_center()
	walk_animator.setup()


func _physics_process(delta: float) -> void:
	velocity = wander_module.get_velocity(delta)
	move_and_slide()
	walk_animator.update_animation(velocity, wander_module.get_facing_direction(), delta)
