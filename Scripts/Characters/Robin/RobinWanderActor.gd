extends CharacterBody2D
class_name RobinWanderActor

signal selected(actor: RobinWanderActor)

const DEFAULT_CLICK_SFX_PATHS := [
	"res://Assets/Audio/SFX/UI/click.ogg",
	"res://Assets/Audio/SFX/UI/ui_click.ogg",
	"res://Assets/Audio/SFX/UI/select.ogg",
	"res://Assets/Audio/SFX/UI/button_click.ogg",
	"res://Assets/Audio/SFX/UI/Click.ogg",
]

@export var start_at_movement_area_center: bool = true
@export var display_name: String = "ロビン"
@export var sprite_click_padding: Vector2 = Vector2(24.0, 24.0)
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea2D
@onready var needs_bundle: Node = $AICharacterNeedsBundle
@onready var needs_module: CharacterNeedsModule = $AICharacterNeedsBundle/CharacterNeedsModule
@onready var need_planner: NeedDrivenAIPlanner = $AICharacterNeedsBundle/NeedDrivenAIPlanner
@onready var inventory_module: RobinInventoryModule = $RobinInventoryModule
@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var sleep_behavior_module: AICharacterSleepBehaviorModule = $AICharacterSleepBehaviorModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator


func _ready() -> void:
	input_pickable = false
	_setup_click_area()
	_load_default_click_sfx_if_needed()
	wander_module.setup(self)
	sleep_behavior_module.setup(self)
	if start_at_movement_area_center:
		global_position = wander_module.get_movement_center()
	walk_animator.setup()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_mouse_inside_sprite_click_rect(mouse_event.global_position):
				_select_actor()


func _physics_process(delta: float) -> void:
	var facing_direction := wander_module.get_facing_direction()
	if sleep_behavior_module != null:
		var sleep_velocity := sleep_behavior_module.get_velocity(delta)
		if sleep_behavior_module.is_active():
			velocity = sleep_velocity
			facing_direction = sleep_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return

	velocity = wander_module.get_velocity(delta)
	move_and_slide()
	if wander_module.clamp_body_to_movement_area():
		velocity = Vector2.ZERO
	walk_animator.update_animation(velocity, facing_direction, delta)


func get_movement_area() -> Rect2:
	return wander_module.get_movement_area()


func get_visual_movement_area() -> Rect2:
	return wander_module.get_visual_movement_area()


func get_needs_module() -> CharacterNeedsModule:
	return needs_module


func get_need_planner() -> NeedDrivenAIPlanner:
	return need_planner


func get_inventory_module() -> RobinInventoryModule:
	return inventory_module


func get_current_need_action_id() -> StringName:
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()


func _setup_click_area() -> void:
	if click_area == null:
		return
	click_area.input_pickable = true
	var callable := Callable(self, "_on_click_area_input_event")
	if not click_area.input_event.is_connected(callable):
		click_area.input_event.connect(callable)


func _on_click_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_select_actor()


func _is_mouse_inside_sprite_click_rect(global_mouse_position: Vector2) -> bool:
	if sprite == null:
		return false
	var local_position := sprite.to_local(global_mouse_position)
	var rect := sprite.get_rect().grow_individual(
		sprite_click_padding.x,
		sprite_click_padding.y,
		sprite_click_padding.x,
		sprite_click_padding.y
	)
	return rect.has_point(local_position)


func _select_actor() -> void:
	_play_click_sfx()
	selected.emit(self)
	get_viewport().set_input_as_handled()


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	for path in DEFAULT_CLICK_SFX_PATHS:
		if ResourceLoader.exists(path):
			click_sfx = load(path) as AudioStream
			return
