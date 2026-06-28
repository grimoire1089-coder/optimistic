extends CharacterBody2D
class_name RobinWanderActor

@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator


func _ready() -> void:
	wander_module.setup(self)
	walk_animator.setup()


func _physics_process(delta: float) -> void:
	velocity = wander_module.get_velocity(delta)
	move_and_slide()
	walk_animator.update_animation(velocity, wander_module.get_facing_direction(), delta)
