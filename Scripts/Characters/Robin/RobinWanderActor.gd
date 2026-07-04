extends CharacterBody2D
class_name RobinWanderActor

signal selected(actor: RobinWanderActor)
signal entrance_travel_completed(target_map_id: StringName)
signal work_started(job_id: StringName)
signal work_completed(job_id: StringName)

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
@onready var read_book_behavior_module: AICharacterReadBookBehaviorModule = $AICharacterReadBookBehaviorModule
@onready var craft_behavior_module: AICharacterCraftBehaviorModule = $AICharacterCraftBehaviorModule
@onready var entrance_travel_behavior_module: AICharacterEntranceTravelBehaviorModule = $AICharacterEntranceTravelBehaviorModule
@onready var action_progress_bar_module: AICharacterActionProgressBarModule = $AICharacterActionProgressBarModule
@onready var action_item_display_module: AICharacterActionItemDisplayModule = $AICharacterActionItemDisplayModule
@onready var walk_animator: RobinWalkSpriteAnimator = $RobinWalkSpriteAnimator

var _connected_room_map: RoomMapGridModule
var _last_actor_top_left_grid_position := AICharacterGridMovementHelper.INVALID_GRID_POSITION


func _ready() -> void:
	input_pickable = false
	_setup_click_area()
	_load_default_click_sfx_if_needed()
	wander_module.setup(self)
	sleep_behavior_module.setup(self)
	hydrate_behavior_module.setup(self)
	hygiene_behavior_module.setup(self)
	sit_behavior_module.setup(self)
	read_book_behavior_module.setup(self)
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
	_connect_room_map_rect_changed()
	_remember_current_actor_grid_position()


func _exit_tree() -> void:
	_disconnect_room_map_rect_changed()


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
			_cancel_read_book_behavior()
			velocity = entrance_travel_velocity
			facing_direction = entrance_travel_behavior_module.get_facing_direction()
			var is_offscreen_working: bool = false
			if entrance_travel_behavior_module.has_method("is_working"):
				is_offscreen_working = entrance_travel_behavior_module.call("is_working") == true
			if not is_offscreen_working:
				move_and_slide()
				if wander_module.clamp_body_to_movement_area(true):
					velocity = Vector2.ZERO
				walk_animator.update_animation(velocity, facing_direction, delta)
			else:
				velocity = Vector2.ZERO
				walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if craft_behavior_module != null:
		var craft_velocity := craft_behavior_module.get_velocity(delta)
		if craft_behavior_module.is_active():
			_cancel_sit_behavior()
			_cancel_read_book_behavior()
			velocity = craft_velocity
			facing_direction = craft_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if sleep_behavior_module != null:
		var sleep_velocity := sleep_behavior_module.get_velocity(delta)
		if sleep_behavior_module.is_active():
			_cancel_sit_behavior()
			_cancel_read_book_behavior()
			velocity = sleep_velocity
			facing_direction = sleep_behavior_module.get_facing_direction()
			if _should_skip_sleep_move_and_slide():
				velocity = Vector2.ZERO
			else:
				move_and_slide()
			if not sleep_behavior_module.is_sleeping() and wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if hydrate_behavior_module != null:
		var hydrate_velocity := hydrate_behavior_module.get_velocity(delta)
		if hydrate_behavior_module.is_active():
			_cancel_sit_behavior()
			_cancel_read_book_behavior()
			velocity = hydrate_velocity
			facing_direction = hydrate_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if hygiene_behavior_module != null:
		var hygiene_velocity := hygiene_behavior_module.get_velocity(delta)
		if hygiene_behavior_module.is_active():
			_cancel_sit_behavior()
			_cancel_read_book_behavior()
			velocity = hygiene_velocity
			facing_direction = hygiene_behavior_module.get_facing_direction()
			move_and_slide()
			if wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if read_book_behavior_module != null:
		var read_velocity := read_book_behavior_module.get_velocity(delta)
		if read_book_behavior_module.is_active():
			_cancel_sit_behavior()
			velocity = read_velocity
			facing_direction = read_book_behavior_module.get_facing_direction()
			move_and_slide()
			if not read_book_behavior_module.is_reading() and wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return
	if sit_behavior_module != null:
		var sit_velocity := sit_behavior_module.get_velocity(delta)
		if sit_behavior_module.is_active():
			velocity = sit_velocity
			facing_direction = sit_behavior_module.get_facing_direction()
			move_and_slide()
			if not sit_behavior_module.is_sitting() and wander_module.clamp_body_to_movement_area(true):
				velocity = Vector2.ZERO
			walk_animator.update_animation(velocity, facing_direction, delta)
			_update_grid_alignment_after_motion()
			return

	velocity = wander_module.get_velocity(delta)
	move_and_slide()
	if wander_module.clamp_body_to_movement_area():
		velocity = Vector2.ZERO
	walk_animator.update_animation(velocity, facing_direction, delta)
	_update_grid_alignment_after_motion()


func request_entrance_travel(entrance: Node2D, target_map_id: StringName) -> bool:
	if entrance_travel_behavior_module == null:
		return false
	if _is_busy_for_entrance_travel():
		return false
	return entrance_travel_behavior_module.request_travel_to_entrance(entrance, target_map_id)


func request_work_at_entrance(job_id: StringName, job_display_name: String, duration_minutes: int) -> bool:
	if entrance_travel_behavior_module == null:
		return false
	if _is_busy_for_entrance_travel():
		return false
	var entrance := _find_work_entrance()
	if entrance == null:
		return false
	if not entrance_travel_behavior_module.has_method("request_work_at_entrance"):
		return false
	return entrance_travel_behavior_module.call(
		"request_work_at_entrance",
		entrance,
		job_id,
		duration_minutes,
		job_display_name
	) == true


func cancel_entrance_travel() -> void:
	if entrance_travel_behavior_module == null:
		return
	entrance_travel_behavior_module.cancel_travel()


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	if craft_behavior_module == null:
		return false
	return craft_behavior_module.request_craft(recipe, quantity)


func request_read_skill_book(book: BookData) -> bool:
	if read_book_behavior_module == null:
		return false
	return read_book_behavior_module.request_read_book(book)


func get_movement_area() -> Rect2:
	return wander_module.get_movement_area()


func get_visual_movement_area() -> Rect2:
	return wander_module.get_visual_movement_area()


func get_grid_movement_area() -> Rect2:
	var room_map := _get_room_map()
	if room_map != null:
		return room_map.get_grid_rect()
	return get_visual_movement_area()


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


func is_working() -> bool:
	if entrance_travel_behavior_module == null:
		return false
	if not entrance_travel_behavior_module.has_method("is_work_requested"):
		return false
	return entrance_travel_behavior_module.call("is_work_requested") == true


func get_current_action_display_text() -> String:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		if entrance_travel_behavior_module.has_method("is_working") and entrance_travel_behavior_module.call("is_working") == true:
			return "アルバイト中"
		if entrance_travel_behavior_module.has_method("is_work_requested") and entrance_travel_behavior_module.call("is_work_requested") == true:
			return "仕事へ移動中"
		return "マップ移動中"
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return "制作中"
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return "水分補給中"
	if hygiene_behavior_module != null and hygiene_behavior_module.is_active():
		return "シャワー中"
	if read_book_behavior_module != null and read_book_behavior_module.is_active():
		if read_book_behavior_module.is_reading():
			return "読書中"
		return "移動中"
	if sit_behavior_module != null and sit_behavior_module.is_active():
		if sit_behavior_module.is_using_lapis():
			return "ラピス操作中"
		return "着席中"
	if is_sleeping():
		return "睡眠中"
	if wander_module != null and wander_module.is_moving():
		return "移動中"
	var action_id := get_current_need_action_id()
	if action_id == CharacterNeedActionIds.IDLE:
		return "暇を持て余している"
	return String(action_id)


func get_current_need_action_id() -> StringName:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		if entrance_travel_behavior_module.has_method("is_work_requested") and entrance_travel_behavior_module.call("is_work_requested") == true:
			return &"part_time_work"
		return &"map_travel"
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return &"crafting"
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return &"hydrating"
	if hygiene_behavior_module != null and hygiene_behavior_module.is_active():
		return &"maintaining"
	if read_book_behavior_module != null and read_book_behavior_module.is_active():
		return &"reading_book"
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
	var did_snap := snap_to_nearest_walkable_grid()
	if wander_module != null:
		wander_module.clamp_body_to_movement_area()
	return reset_any or did_snap


func debug_reset_all_actions() -> bool:
	var reset_any := false
	reset_any = _debug_reset_behavior(entrance_travel_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(craft_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(sleep_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(hydrate_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(hygiene_behavior_module) or reset_any
	reset_any = _debug_reset_behavior(read_book_behavior_module) or reset_any
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
	var cell_size := room_map.get_cell_size()
	var screen_cell_size := room_map.get_screen_cell_size() if room_map.has_method("get_screen_cell_size") else cell_size
	return "grid=%s footprint=%s cell=(%.1f, %.1f) screen_cell=(%.1f, %.1f) walkable=%s pos=(%.1f, %.1f)" % [
		str(top_left),
		str(footprint),
		cell_size.x,
		cell_size.y,
		screen_cell_size.x,
		screen_cell_size.y,
		str(can_stand),
		global_position.x,
		global_position.y,
	]


func _snap_start_position_to_grid_deferred() -> void:
	if not snap_start_position_to_grid:
		return
	snap_to_nearest_walkable_grid()
	_remember_current_actor_grid_position()


func _update_grid_alignment_after_motion() -> void:
	_connect_room_map_rect_changed()
	_remember_current_actor_grid_position()


func _connect_room_map_rect_changed() -> void:
	var room_map := _get_room_map()
	if _connected_room_map == room_map:
		return
	_disconnect_room_map_rect_changed()
	if room_map == null:
		return
	_connected_room_map = room_map
	var callable := Callable(self, "_on_room_map_rect_changed")
	if not _connected_room_map.map_rect_changed.is_connected(callable):
		_connected_room_map.map_rect_changed.connect(callable)


func _disconnect_room_map_rect_changed() -> void:
	if _connected_room_map == null:
		return
	var callable := Callable(self, "_on_room_map_rect_changed")
	if is_instance_valid(_connected_room_map) and _connected_room_map.map_rect_changed.is_connected(callable):
		_connected_room_map.map_rect_changed.disconnect(callable)
	_connected_room_map = null


func _on_room_map_rect_changed(_visual_rect: Rect2, _grid_rect: Rect2, _grid_size: Vector2i) -> void:
	_realign_to_cached_grid_position()
	_notify_room_map_changed_to_movement_modules()
	_remember_current_actor_grid_position()


func _realign_to_cached_grid_position() -> void:
	var room_map := _get_room_map()
	if room_map == null:
		return

	var footprint := _get_debug_actor_grid_footprint()
	var top_left_cell := _last_actor_top_left_grid_position
	if not _is_valid_debug_grid_position(top_left_cell) or not room_map.is_grid_area_inside(top_left_cell, footprint):
		top_left_cell = _get_actor_top_left_grid_position(footprint)
	if not _is_valid_debug_grid_position(top_left_cell) or not room_map.is_grid_area_inside(top_left_cell, footprint):
		return

	var target_position := room_map.grid_to_world_area_center(top_left_cell, footprint)
	if global_position.distance_squared_to(target_position) <= 0.001:
		return
	global_position = target_position
	velocity = Vector2.ZERO


func _notify_room_map_changed_to_movement_modules() -> void:
	if wander_module != null and wander_module.has_method("handle_room_map_changed"):
		wander_module.call("handle_room_map_changed")


func _remember_current_actor_grid_position() -> void:
	var footprint := _get_debug_actor_grid_footprint()
	var top_left_cell := _get_actor_top_left_grid_position(footprint)
	var room_map := _get_room_map()
	if room_map == null:
		return
	if not _is_valid_debug_grid_position(top_left_cell):
		return
	if not room_map.is_grid_area_inside(top_left_cell, footprint):
		return
	_last_actor_top_left_grid_position = top_left_cell


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


func _cancel_read_book_behavior() -> void:
	if read_book_behavior_module == null:
		return
	if not read_book_behavior_module.is_active():
		return
	read_book_behavior_module.cancel_reading()


func _is_busy_for_entrance_travel() -> bool:
	if entrance_travel_behavior_module != null and entrance_travel_behavior_module.is_active():
		return true
	if craft_behavior_module != null and craft_behavior_module.is_active():
		return true
	if sleep_behavior_module != null and sleep_behavior_module.is_active():
		return true
	if hydrate_behavior_module != null and hydrate_behavior_module.is_active():
		return true
	if hygiene_behavior_module != null and hygiene_behavior_module.is_active():
		return true
	if read_book_behavior_module != null and read_book_behavior_module.is_active():
		return true
	return false


func _connect_entrance_travel_signal() -> void:
	if entrance_travel_behavior_module == null:
		return
	var travel_callable := Callable(self, "_on_entrance_travel_completed")
	if not entrance_travel_behavior_module.travel_completed.is_connected(travel_callable):
		entrance_travel_behavior_module.travel_completed.connect(travel_callable)
	if entrance_travel_behavior_module.has_signal("work_started"):
		var work_started_callable := Callable(self, "_on_entrance_work_started")
		if not entrance_travel_behavior_module.work_started.is_connected(work_started_callable):
			entrance_travel_behavior_module.work_started.connect(work_started_callable)
	if entrance_travel_behavior_module.has_signal("work_completed"):
		var work_completed_callable := Callable(self, "_on_entrance_work_completed")
		if not entrance_travel_behavior_module.work_completed.is_connected(work_completed_callable):
			entrance_travel_behavior_module.work_completed.connect(work_completed_callable)


func _on_entrance_travel_completed(target_map_id: StringName) -> void:
	entrance_travel_completed.emit(target_map_id)


func _on_entrance_work_started(job_id: StringName) -> void:
	work_started.emit(job_id)


func _on_entrance_work_completed(job_id: StringName) -> void:
	work_completed.emit(job_id)


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
		return AICharacterGridMovementHelper.INVALID_GRID_POSITION
	return AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		room_map,
		world_position,
		footprint,
		Callable(self, "_is_debug_grid_area_walkable"),
		AICharacterGridMovementHelper.INVALID_GRID_POSITION
	)


func _is_debug_grid_area_walkable(top_left_cell: Vector2i, footprint: Vector2i) -> bool:
	var room_map := _get_room_map()
	if room_map == null:
		return false
	var safe_footprint := AICharacterGridMovementHelper.get_safe_footprint(footprint)
	if not room_map.is_grid_area_inside(top_left_cell, safe_footprint):
		return false
	var furniture_placement := _get_furniture_placement_module()
	if furniture_placement != null and furniture_placement.has_method("can_place_at"):
		return furniture_placement.call("can_place_at", top_left_cell, safe_footprint) == true
	return true


func _get_actor_top_left_grid_position(footprint: Vector2i) -> Vector2i:
	var room_map := _get_room_map()
	if room_map == null:
		return AICharacterGridMovementHelper.INVALID_GRID_POSITION
	return AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
		room_map,
		global_position,
		footprint,
		AICharacterGridMovementHelper.INVALID_GRID_POSITION
	)


func _get_debug_actor_grid_footprint() -> Vector2i:
	return AICharacterGridMovementHelper.get_safe_footprint(debug_actor_grid_footprint)


func _get_room_map() -> RoomMapGridModule:
	return get_node_or_null("../RobinRoomMap") as RoomMapGridModule


func _get_active_room_map() -> RoomMapGridModule:
	var map_travel_module := get_node_or_null("../MainSceneMapTravelModule")
	if map_travel_module == null:
		return null
	if not map_travel_module.has_method("get_active_map"):
		return null
	return map_travel_module.call("get_active_map") as RoomMapGridModule


func _find_work_entrance() -> Node2D:
	var active_map := _get_active_room_map()
	var entrance := _find_entrance_in_room_map(active_map)
	if entrance != null:
		return entrance
	return _find_entrance_in_room_map(_get_room_map())


func _find_entrance_in_room_map(room_map: RoomMapGridModule) -> Node2D:
	if room_map == null:
		return null
	var furniture_root := room_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return null
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if furniture is EntranceFurniture:
			return furniture
		if furniture.has_meta("furniture_id") and StringName(furniture.get_meta("furniture_id", &"")) == &"entrance":
			return furniture
	return null


func _get_furniture_placement_module() -> Node:
	return get_node_or_null("../FurniturePlacementModule")


func _is_valid_debug_grid_position(grid_position: Vector2i) -> bool:
	return AICharacterGridMovementHelper.is_valid_grid_position(
		grid_position,
		AICharacterGridMovementHelper.INVALID_GRID_POSITION
	)


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false
