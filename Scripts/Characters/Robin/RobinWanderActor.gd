extends CharacterBody2D
class_name RobinWanderActor

signal selected(actor: RobinWanderActor)

@export var start_at_movement_area_center: bool = true
@export var display_name: String = "ロビン"

@onready var needs_bundle: Node = $AICharacterNeedsBundle
@onready var needs_module: CharacterNeedsModule = $AICharacterNeedsBundle/CharacterNeedsModule
@onready var need_planner: NeedDrivenAIPlanner = $AICharacterNeedsBundle/NeedDrivenAIPlanner
@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator


func _ready() -> void:
	input_pickable = true
	wander_module.setup(self)
	if start_at_movement_area_center:
		global_position = wander_module.get_movement_center()
	walk_animator.setup()


func _physics_process(delta: float) -> void:
	velocity = wander_module.get_velocity(delta)
	move_and_slide()
	if wander_module.clamp_body_to_movement_area():
		velocity = Vector2.ZERO
	walk_animator.update_animation(velocity, wander_module.get_facing_direction(), delta)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			selected.emit(self)
			get_viewport().set_input_as_handled()


func get_movement_area() -> Rect2:
	return wander_module.get_movement_area()


func get_needs_module() -> CharacterNeedsModule:
	return needs_module


func get_need_planner() -> NeedDrivenAIPlanner:
	return need_planner


func get_current_need_action_id() -> StringName:
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()
