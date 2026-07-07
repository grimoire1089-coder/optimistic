extends CharacterBody2D
class_name ZippyActor

signal selected(actor: ZippyActor)

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var resident_id: StringName = &"zippy"
@export var display_name: String = "ジッピー"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea2D
@onready var needs_bundle: Node = $AICharacterNeedsBundle
@onready var needs_module: CharacterNeedsModule = $AICharacterNeedsBundle/CharacterNeedsModule
@onready var mood_module: CharacterMoodModule = $AICharacterNeedsBundle/CharacterMoodModule
@onready var need_planner: NeedDrivenAIPlanner = $AICharacterNeedsBundle/NeedDrivenAIPlanner


func _ready() -> void:
	input_pickable = false
	_load_default_click_sfx_if_needed()
	_connect_click_area()


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
	var action_id := get_current_need_action_id()
	if action_id == CharacterNeedActionIds.IDLE:
		return "待機中"
	return String(action_id)


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


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream
