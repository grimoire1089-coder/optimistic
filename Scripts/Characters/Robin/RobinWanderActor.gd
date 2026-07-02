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
@export var snap_start_position_to_grid: bool = true
@export var debug_actor_grid_footprint: Vector2i = Vector2i(2, 4)
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
@onready var skills_module: AICharacterSkillsModule = $AICharacterSkillsModule
@onready var inventory_module: RobinInventoryModule = $RobinInventoryModule
@onready var wander_module: RobinRandomWanderModule = $RobinRandomWanderModule
@onready var sleep_behavior_module: AICharacterSleepBehaviorModule = $AICharacterSleepBehaviorModule
@onready var hydrate_behavior_module: AICharacterHydrateBehaviorModule = $AICharacterHydrateBehaviorModule
@onready var hygiene_behavior_module: AICharacterHygieneBehaviorModule = $AICharacterHygieneBehaviorModule
@onready var sit_behavior_module: AICharacterSitBehaviorModule = $AICharacterSitBehaviorModule
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
	hygiene_behavior_module.setup(self)
	sit_behavior_module.setup(self)
	craft_behavior_module.setup(self)	
	entrance_travel_behavior_module.setup(self)
	_connect_entrance_travel_signal()
	action_progress_bar_module.setup(self)
	action_item_display_module.setup(self)
	if start_at_movement_area_center:
		global_position = wander_module.get_movement_center()
	if snap_start_position_to_grid:
		call_deferred("_snap_start_position_to_grid_deferred")
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
			_cancel_sit_behavior()
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
			_cancel_sit_behavior()
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
			_cancel_sit_behavior()
			velocity = sleep_velocity
			facing_direction = sleep_behavior_module.get_facing_direction()
			if _should_skip_sleep_move_and_slide():
				velocity = Vector2.ZERO
			else:
				move_and_slide()
			if not sleep_behavior_module.is_sleeping() and wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if hydrate_behavior_module != null:
		var hydrate_velocity := hydrate_behavior_module.get_velocity(delta)
		if hydrate_behavior_module.is_active():
			_cancel_sit_behavior()
			velocity = hydrate_velocity
			facing_direction = hydrate_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if hygiene_behavior_module != null:
		var hygiene_velocity := hygiene_behavior_module.get_velocity(delta)
		if hygiene_behavior_module.is_active():
			_cancel_sit_behavior()
			velocity = hygiene_velocity
			facing_direction = hygiene_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area():
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			return
	if sit_behavior_module != null:
		var sit_velocity := sit_behavior_module.get_velocity(delta)
		if sit_behavior_module.is_active():
			velocity = sit_velocity
			facing_direction = sit_behavior_module.get_facing_direction()
			move_and_slide()
			if not sit_behavior_module.is_sitting() and wander_module.clamp_body_to_movement_area():
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


func get_skills_module() -> AICharacterSkillsModule:
	return skills_module


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
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return "水分補給中"
	if hygiene_behavior_module != null and hygiene_behavior_module.is_active():
		return "シャワー中"
	if sit_behavior_module != null and sit_behavior_module.is_active():
		if sit_behavior_module.is_using_lapis():
			return "ラピス操作中"
		return "着席中"
	if is_sleeping():
		return "睡眠中"
	return String(get_current_need_action_id())


func get_current_need_action_id() -> StringName:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		return &"map_travel"
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return &"crafting"
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return &"hydrating"
	if hygiene_behavior_module != null and hygiene_behavior_module.is_active():
		return &"maintaining"
	if sit_behavior_module != null and sit_behavior_module.is_active():
		return &"sitting"
	if is_sleeping():
		return &"sleeping"
	if need_planner == null:
		return CharacterNeedActionIds.IDLE
	return need_planner.get_next_action_id()


func get_current_lowest_need_id() -> StringName:
	if needs_module == null:
		return &""
	return needs_module.get_lowest_need_id()


func debug_reset_actions_and_snap_to_grid() -> bool:
	var reset_any := debug_reset_all_actions()
	velocity = Vector2.ZERO
	var snapped := snap_to_nearest_walkable_grid()
	if wander_module != null:
		wander_module.clamp_body_to_movement_area()
	return reset_any or snapped


func debug_reset_all_actions() -> bool:
	var reset_any := false
	reset_any = _debug_reset_behavior(entrance_travel_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(craft_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(sleep_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(hydrate_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(hygiene_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(sit_behavior_module) or reset_any
	velocity = Vector2.ZERO
	return reset_any


func snap_to_nearest_walkable_grid() -> bool:
	var room_map := _get_room_map()
	if room_map == null:
		if wander_module != null:
			return wander_module.clamp_body_to_movement_area()
		return false

	var footprint := _get_debug_actor_grid_footprint()
	var nearest_cell := _get_nearest_walkable_top_left_cell(global_position, footprint)
	if not _is_valid_debug_grid_position(nearest_cell):
		return false

	var snapped_position := room_map.grid_to_world_area_center(nearest_cell, footprint)
	var changed := global_position.distance_squared_to(snapped_position) > 0.001
	global_position = snapped_position
	velocity = Vector2.ZERO
	if wander_module != null:
		wander_module.clamp_body_to_movement_area()
	return changed


func get_debug_actor_grid_summary() -> String:
	var room_map := _get_room_map()
	if room_map == null:
		return "grid: no room map"
	var footprint := _get_debug_actor_grid_footprint()
	var top_left := _get_actor_top_left_grid_position(footprint)
	var can_stand := _is_debug_grid_area_walkable(top_left, footprint)
	return "grid=%s footprint=%s walkable=%s pos=(%.1f, %.1f)" % [
		str(top_left),
		str(footprint),
		str(can_stand),
		global_position.x,
		global_position.y,
	]


func _snap_start_position_to_grid_deferred() -> void:
	if not snap_start_position_to_grid:
		return
	snap_to_nearest_walkable_grid()


func _should_skip_sleep_move_and_slide() -> bool:
	if sleep_behavior_module == null:
		return false
	if sleep_behavior_module.is_sleeping():
		return false
	var direct_movement_value: Variant = sleep_behavior_module.get("use_direct_grid_path_movement")
	return bool(direct_movement_value)


func _cancel_sit_behavior() -> void:
	if sit_behavior_module == null:
		return
	if not sit_behavior_module.is_active():
		return
	sit_behavior_module.cancel_sitting()


func _debug_reset_behavior(behavior: Node) -> bool:
	if behavior == null:
		return false
	var was_active := _is_behavior_active_for_debug(behavior)

	if behavior.has_method("debug_reset_action"):
		behavior.call("debug_reset_action")
		return true
	if behavior.has_method("cancel_travel"):
		behavior.call("cancel_travel")
		return true
	if behavior.has_method("cancel_sitting"):
		behavior.call("cancel_sitting")
		return true

	if behavior.has_method("_stop_sleeping"):
		behavior.call("_stop_sleeping")
		return true
	if behavior.has_method("_reset_action"):
		behavior.call("_reset_action")
		return true
	if behavior.has_method("_finish_hydrate_action"):
		_debug_set_property_if_exists(behavior, &"_is_drinking", false)
		_debug_set_property_if_exists(behavior, &"_drink_food_data", null)
		behavior.call("_finish_hydrate_action")
		return true
	if behavior.has_method("_finish_hygiene_action"):
		_debug_set_property_if_exists(behavior, &"_is_showering", false)
		behavior.call("_finish_hygiene_action")
		return true

	_debug_set_property_if_exists(behavior, &"_is_active", false)
	_debug_set_property_if_exists(behavior, &"_path_cells", [])
	return was_active


func _is_behavior_active_for_debug(behavior: Node) -> bool:
	if behavior == null:
		return false
	if not behavior.has_method("is_active"):
		return false
	return behavior.call("is_active") == true


func _debug_set_property_if_exists(object: Object, property_name: StringName, value: Variant) -> void:
	if object == null:
		return
	if not _has_property(object, property_name):
		return
	object.set(property_name, value)


func _get_nearest_walkable_top_left_cell(world_position: Vector2, footprint: Vector2i) -> Vector2i:
	var room_map := _get_room_map()
	if room_map == null:
		return Vector2i(-999999, -999999)
	var grid_size := room_map.get_grid_size()
	var safe_footprint := Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	var max_x := grid_size.x - safe_footprint.x
	var max_y := grid_size.y - safe_footprint.y
	if max_x < 0 or max_y < 0:
		return Vector2i(-999999, -999999)

	var nearest_cell := Vector2i(-999999, -999999)
	var nearest_distance := INF
	for y in range(max_y + 1):
		for x in range(max_x + 1):
			var cell := Vector2i(x, y)
			if not _is_debug_grid_area_walkable(cell, safe_footprint):
				continue
			var center := room_map.grid_to_world_area_center(cell, safe_footprint)
			var distance := world_position.distance_squared_to(center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
	return nearest_cell


func _is_debug_grid_area_walkable(top_left_cell: Vector2i, footprint: Vector2i) -> bool:
	var room_map := _get_room_map()
	if room_map == null:
		return false
	var safe_footprint := Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	if not room_map.is_grid_area_inside(top_left_cell, safe_footprint):
		return false
	var furniture_placement := _get_furniture_placement_module()
	if furniture_placement != null and furniture_placement.has_method("can_place_at"):
		return furniture_placement.call("can_place_at", top_left_cell, safe_footprint) == true
	return true


func _get_actor_top_left_grid_position(footprint: Vector2i) -> Vector2i:
	var room_map := _get_room_map()
	if room_map == null:
		return Vector2i(-999999, -999999)
	var safe_footprint := Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	var center_cell := room_map.world_to_grid(global_position)
	return center_cell - Vector2i(floori(float(safe_footprint.x) * 0.5), floori(float(safe_footprint.y) * 0.5))


func _get_debug_actor_grid_footprint() -> Vector2i:
	return Vector2i(maxi(debug_actor_grid_footprint.x, 1), maxi(debug_actor_grid_footprint.y, 1))


func _get_room_map() -> RoomMapGridModule:
	return get_node_or_null("../RobinRoomMap") as RoomMapGridModule


func _get_furniture_placement_module() -> Node:
	return get_node_or_null("../FurniturePlacementModule")


func _is_valid_debug_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != Vector2i(-999999, -999999)


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false
