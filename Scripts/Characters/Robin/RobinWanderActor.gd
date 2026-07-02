extends CharacterBody2D
class_name RobinWanderActor

signal selected(actor: RobinWanderActor)
signal entrance_travel_completed(target_map_id: StringName)

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
@onready var mood_module: CharacterMoodModule = $AICharacterNeedsBundle/CharacterMoodModule
@onready var need_planner: NeedDrivenAIPlanner = $AICharacterNeedsBundle/NeedDrivenAIPlanner
@onready var inventory_module: RobinInventoryModule = $RobinInventoryModule
@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var sleep_behavior_module: AICharacterSleepBehaviorModule = $AICharacterSleepBehaviorModule
@onready var hydrate_behavior_module: AICharacterHydrateBehaviorModule = $AICharacterHydrateBehaviorModule
@onready var craft_behavior_module: AICharacterCraftBehaviorModule = $AICharacterCraftBehaviorModule
@onready var entrance_travel_behavior_module: AICharacterEntranceTravelBehaviorModule = $AICharacterEntranceTravelBehaviorModule
@onready var action_progress_bar_module: AICharacterActionProgressBarModule = $AICharacterActionProgressBarModule
@onready var action_item_display_module: AICharacterActionItemDisplayModule = $AICharacterActionItemDisplayModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator


func _ready() -> void:
	input_pickable = false
	_setup_click_area()
	_load_default_click_sfx_if_needed()
	wander_module.setup(self)
	sleep_behavior_module.setup(self)
	hydrate_behavior_module.setup(self)
	craft_behavior_module.setup(self)
	entrance_travel_behavior_module.setup(self)
	_connect_entrance_travel_signal()
	action_progress_bar_module.setup(self)
	action_item_display_module.setup(self)
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
	if entrance_travel_behavior_module != null:
		var entrance_travel_velocity := entrance_travel_behavior_module.get_velocity(delta)
		if entrance_travel_behavior_module.is_active():
			velocity = entrance_travel_velocity
			facing_direction = entrance_travel_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if craft_behavior_module != null:
		var craft_velocity := craft_behavior_module.get_velocity(delta)
		if craft_behavior_module.is_active():
			velocity = craft_velocity
			facing_direction = craft_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if sleep_behavior_module != null:
		var sleep_velocity := sleep_behavior_module.get_velocity(delta)
		if sleep_behavior_module.is_active():
			velocity = sleep_velocity
			facing_direction = sleep_behavior_module.get_facing_direction()
			move_and_slide()
			if not sleep_behavior_module.is_sleeping() and wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if hydrate_behavior_module != null:
		var hydrate_velocity := hydrate_behavior_module.get_velocity(delta)
		if hydrate_behavior_module.is_active():
			velocity = hydrate_velocity
			facing_direction = hydrate_behavior_module.get_facing_direction()
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


func request_entrance_travel(entrance: Node2D, target_map_id: StringName) -> bool:
	if entrance_travel_behavior_module == null:
		return false
	if _is_busy_for_entrance_travel():
		return false
	return entrance_travel_behavior_module.request_travel_to_entrance(entrance, target_map_id)


func cancel_entrance_travel() -> void:
	if entrance_travel_behavior_module == null:
		return
	entrance_travel_behavior_module.cancel_travel()


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	if craft_behavior_module == null:
		return false
	return craft_behavior_module.request_craft(recipe, quantity)


func get_movement_area() -> Rect2:
	return wander_module.get_movement_area()


func get_visual_movement_area() -> Rect2:
	return wander_module.get_visual_movement_area()


func get_needs_module() -> CharacterNeedsModule:
	return needs_module


func get_mood_module() -> CharacterMoodModule:
	return mood_module


func get_need_planner() -> NeedDrivenAIPlanner:
	return need_planner


func get_inventory_module() -> RobinInventoryModule:
	return inventory_module


func get_craft_behavior_module() -> AICharacterCraftBehaviorModule:
	return craft_behavior_module


func is_sleeping() -> bool:
	if sleep_behavior_module == null:
		return false
	return sleep_behavior_module.is_sleeping()


func get_current_action_display_text() -> String:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		return "マップ移動中"
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return "制作中"
	if is_sleeping():
		return "睡眠中"
	return String(get_current_need_action_id())


func get_current_need_action_id() -> StringName:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		return &"map_travel"
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return &"crafting"
	if is_sleeping():
		return &"sleeping"
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()


func _is_busy_for_entrance_travel() -> bool:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		return true
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return true
	if sleep_behavior_module != null and sleep_behavior_module.is_active():
		return true
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return true
	return false


func _connect_entrance_travel_signal() -> void:
	if entrance_travel_behavior_module == null:
		return
	var callable := Callable(self, "_on_entrance_travel_completed")
	if not entrance_travel_behavior_module.travel_completed.is_connected(callable):
		entrance_travel_behavior_module.travel_completed.connect(callable)


func _on_entrance_travel_completed(target_map_id: StringName) -> void:
	entrance_travel_completed.emit(target_map_id)


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
