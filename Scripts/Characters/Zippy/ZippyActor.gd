extends CharacterBody2D
class_name ZippyActor

signal selected(actor: ZippyActor)

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const WANDER_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterRandomWanderModule.gd")

@export var resident_id: StringName = &"zippy"
@export var display_name: String = "ジッピー"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var ai_character_hud_path: NodePath = NodePath("../CanvasLayer/AICharacterHud")
@export var snap_start_position_to_grid: bool = true
@export var start_grid_position: Vector2i = Vector2i(1, 6)
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea2D
@onready var needs_bundle: Node = $AICharacterNeedsBundle
@onready var needs_module: CharacterNeedsModule = $AICharacterNeedsBundle/CharacterNeedsModule
@onready var mood_module: CharacterMoodModule = $AICharacterNeedsBundle/CharacterMoodModule
@onready var need_planner: NeedDrivenAIPlanner = $AICharacterNeedsBundle/NeedDrivenAIPlanner

var wander_module: AICharacterRandomWanderModule


func _ready() -> void:
	input_pickable = false
	add_to_group(&"ai_character_actor")
	_load_default_click_sfx_if_needed()
	_connect_click_area()
	_ensure_wander_module()
	call_deferred("_finish_start_setup")


func _physics_process(delta: float) -> void:
	if wander_module == null:
		return
	velocity = wander_module.get_velocity(delta)
	if velocity.length_squared() > 0.0:
		move_and_slide()


func get_actor_grid_footprint() -> Vector2i:
	return actor_grid_footprint


func is_ai_character_moving() -> bool:
	return wander_module != null and wander_module.is_moving()


func get_needs_module() -> CharacterNeedsModule:
	return needs_module


func get_mood_module() -> CharacterMoodModule:
	return mood_module


func get_need_planner() -> NeedDrivenAIPlanner:
	return need_planner


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()


func get_current_need_action_id() -> StringName:
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_action_display_text() -> String:
	if wander_module != null and wander_module.is_moving():
		return "移動中"
	var action_id := get_current_need_action_id()
	if action_id == CharacterNeedActionIds.IDLE:
		return "待機中"
	return String(action_id)


func _ensure_wander_module() -> void:
	wander_module = get_node_or_null("AICharacterRandomWanderModule") as AICharacterRandomWanderModule
	if wander_module != null:
		return
	wander_module = WANDER_SCRIPT.new() as AICharacterRandomWanderModule
	if wander_module == null:
		return
	wander_module.name = "AICharacterRandomWanderModule"
	wander_module.movement_area_provider_path = NodePath("../RobinRoomMap")
	wander_module.furniture_placement_module_path = NodePath("../FurniturePlacementModule")
	wander_module.actor_grid_footprint = actor_grid_footprint
	wander_module.visual_half_extents = Vector2(48.0, 96.0)
	wander_module.idle_chance = 0.72
	add_child(wander_module)


func _finish_start_setup() -> void:
	if snap_start_position_to_grid:
		_snap_start_position_to_grid()
	if wander_module != null:
		wander_module.setup(self)


func _snap_start_position_to_grid() -> void:
	var room_map := get_node_or_null(room_map_path) as RoomMapGridModule
	if room_map == null:
		return
	if not room_map.is_grid_area_inside(start_grid_position, actor_grid_footprint):
		return
	global_position = room_map.grid_to_world_area_center(start_grid_position, actor_grid_footprint)


func _connect_click_area() -> void:
	if click_area == null:
		return
	var callable := Callable(self, "_on_click_area_input_event")
	if not click_area.input_event.is_connected(callable):
		click_area.input_event.connect(callable)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			_play_click_sfx()
			selected.emit(self)
			_toggle_ai_character_hud()


func _toggle_ai_character_hud() -> void:
	if _is_build_mode_enabled():
		return
	var hud := get_node_or_null(ai_character_hud_path)
	if hud == null or not hud.has_method("toggle_actor"):
		return
	hud.call("toggle_actor", self)


func _is_build_mode_enabled() -> bool:
	var controller := get_tree().get_first_node_in_group(&"build_mode_controller")
	if controller == null or not controller.has_method("is_build_mode_enabled"):
		return false
	return bool(controller.call("is_build_mode_enabled"))


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream
