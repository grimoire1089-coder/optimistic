extends CharacterBody2D
class_name ZippyActor

signal selected(actor: ZippyActor)

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_LAPIS_ITEM_PATH := "res://Data/Items/Tools/Lapis_001.tres"
const WANDER_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterRandomWanderModule.gd")
const SIT_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterReservedSitBehaviorModule.gd")
const HYDRATE_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterTableSeatHydrateModule.gd")
const ITEM_DISPLAY_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterActionItemDisplayModule.gd")
const INVENTORY_SCRIPT := preload("res://Scripts/Characters/Modules/AICharacterInventoryModule.gd")
const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

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
var inventory_module: AICharacterInventoryModule
var hydrate_behavior_module: AICharacterTableSeatHydrateModule
var sit_behavior_module: AICharacterReservedSitBehaviorModule
var action_item_display_module: AICharacterActionItemDisplayModule


func _ready() -> void:
	input_pickable = false
	add_to_group(&"ai_character_actor")
	_register_existing_ai_actors()
	_load_default_click_sfx_if_needed()
	_connect_click_area()
	_ensure_inventory_module()
	_ensure_wander_module()
	_ensure_hydrate_behavior_module()
	_ensure_sit_behavior_module()
	_ensure_action_item_display_module()
	call_deferred("_finish_start_setup")


func _physics_process(delta: float) -> void:
	if _update_hydrate_behavior(delta):
		return
	if _update_sit_behavior(delta):
		return
	if wander_module == null:
		return
	velocity = wander_module.get_velocity(delta)
	if velocity.length_squared() > 0.0:
		move_and_slide()


func get_actor_grid_footprint() -> Vector2i:
	return actor_grid_footprint


func is_ai_character_moving() -> bool:
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active() and velocity.length_squared() > 0.01:
		return true
	if sit_behavior_module != null and sit_behavior_module.is_active() and velocity.length_squared() > 0.01:
		return true
	return wander_module != null and wander_module.is_moving()


func get_needs_module() -> CharacterNeedsModule:
	return needs_module


func get_mood_module() -> CharacterMoodModule:
	return mood_module


func get_need_planner() -> NeedDrivenAIPlanner:
	return need_planner


func get_inventory_module() -> AICharacterInventoryModule:
	return inventory_module


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()


func get_current_need_action_id() -> StringName:
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return CharacterNeedActionIds.HYDRATE
	if sit_behavior_module != null and sit_behavior_module.is_active():
		return &"sitting"
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_action_display_text() -> String:
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		if hydrate_behavior_module.is_drinking():
			return "水分補給中"
		return "水分補給へ移動中"
	if sit_behavior_module != null and sit_behavior_module.is_active():
		if sit_behavior_module.is_sitting():
			return "着席中"
		return "椅子へ移動中"
	if wander_module != null and wander_module.is_moving():
		return "移動中"
	var action_id := get_current_need_action_id()
	if action_id == CharacterNeedActionIds.IDLE:
		return "待機中"
	return String(action_id)


func _register_existing_ai_actors() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for child in parent_node.get_children():
		var node := child as Node
		if node == null or node == self:
			continue
		if node is Node2D and node.has_method("get_needs_module"):
			node.add_to_group(&"ai_character_actor")


func _update_hydrate_behavior(delta: float) -> bool:
	if hydrate_behavior_module == null:
		return false
	var hydrate_velocity := hydrate_behavior_module.get_velocity(delta)
	if not hydrate_behavior_module.is_active():
		return false
	if sit_behavior_module != null and sit_behavior_module.is_active():
		sit_behavior_module.cancel_sitting()
	velocity = hydrate_velocity
	if velocity.length_squared() <= 0.0:
		MoveSlot.release_move(self)
		return true
	if not _try_claim_move_slot():
		velocity = Vector2.ZERO
		return true
	move_and_slide()
	return true


func _update_sit_behavior(delta: float) -> bool:
	if sit_behavior_module == null:
		return false
	var sit_velocity := sit_behavior_module.get_velocity(delta)
	if not sit_behavior_module.is_active():
		return false
	velocity = sit_velocity
	if velocity.length_squared() <= 0.0:
		MoveSlot.release_move(self)
		return true
	if not _try_claim_move_slot():
		velocity = Vector2.ZERO
		return true
	move_and_slide()
	return true


func _try_claim_move_slot() -> bool:
	if MoveSlot.can_move(self):
		return MoveSlot.request_move(self)
	if MoveSlot.is_other_actor_moving(self, &"ai_character_actor"):
		return false
	return MoveSlot.request_move(self)


func _ensure_inventory_module() -> void:
	inventory_module = get_node_or_null("AICharacterInventoryModule") as AICharacterInventoryModule
	if inventory_module != null:
		return
	inventory_module = INVENTORY_SCRIPT.new() as AICharacterInventoryModule
	if inventory_module == null:
		return
	inventory_module.name = "AICharacterInventoryModule"
	inventory_module.slots_per_category = 8
	inventory_module.owner_display_name = display_name
	inventory_module.initial_item_paths = PackedStringArray([DEFAULT_LAPIS_ITEM_PATH])
	add_child(inventory_module)


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


func _ensure_hydrate_behavior_module() -> void:
	hydrate_behavior_module = get_node_or_null("AICharacterTableSeatHydrateModule") as AICharacterTableSeatHydrateModule
	if hydrate_behavior_module != null:
		return
	hydrate_behavior_module = HYDRATE_SCRIPT.new() as AICharacterTableSeatHydrateModule
	if hydrate_behavior_module == null:
		return
	hydrate_behavior_module.name = "AICharacterTableSeatHydrateModule"
	hydrate_behavior_module.inventory_module_path = NodePath("../AICharacterInventoryModule")
	hydrate_behavior_module.actor_grid_footprint = actor_grid_footprint
	hydrate_behavior_module.hydrate_request_ratio = 0.5
	hydrate_behavior_module.nearby_refill_distance = 48.0
	hydrate_behavior_module.refill_cooldown_seconds = 0.0
	hydrate_behavior_module.apply_need_effect_after_refill = true
	hydrate_behavior_module.drink_duration_seconds = 3.0
	hydrate_behavior_module.snap_to_connected_dining_seat_when_drinking = true
	add_child(hydrate_behavior_module)


func _ensure_sit_behavior_module() -> void:
	sit_behavior_module = get_node_or_null("AICharacterReservedSitBehaviorModule") as AICharacterReservedSitBehaviorModule
	if sit_behavior_module != null:
		return
	sit_behavior_module = SIT_SCRIPT.new() as AICharacterReservedSitBehaviorModule
	if sit_behavior_module == null:
		return
	sit_behavior_module.name = "AICharacterReservedSitBehaviorModule"
	sit_behavior_module.actor_grid_footprint = actor_grid_footprint
	sit_behavior_module.idle_lapis_chance = 0.18
	sit_behavior_module.sit_duration_range = Vector2(8.0, 16.0)
	sit_behavior_module.retry_cooldown_range = Vector2(6.0, 12.0)
	add_child(sit_behavior_module)


func _ensure_action_item_display_module() -> void:
	action_item_display_module = get_node_or_null("AICharacterActionItemDisplayModule") as AICharacterActionItemDisplayModule
	if action_item_display_module != null:
		return
	action_item_display_module = ITEM_DISPLAY_SCRIPT.new() as AICharacterActionItemDisplayModule
	if action_item_display_module == null:
		return
	action_item_display_module.name = "AICharacterActionItemDisplayModule"
	action_item_display_module.hydrate_behavior_path = NodePath("../AICharacterTableSeatHydrateModule")
	action_item_display_module.sit_behavior_path = NodePath("../AICharacterReservedSitBehaviorModule")
	action_item_display_module.item_center_offset = Vector2(0.0, -18.0)
	action_item_display_module.item_display_size = Vector2(70.0, 70.0)
	add_child(action_item_display_module)


func _finish_start_setup() -> void:
	if snap_start_position_to_grid:
		_snap_start_position_to_grid()
	if wander_module != null:
		wander_module.setup(self)
	if hydrate_behavior_module != null:
		hydrate_behavior_module.setup(self)
	if sit_behavior_module != null:
		sit_behavior_module.setup(self)
	if action_item_display_module != null:
		action_item_display_module.setup(self)


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
