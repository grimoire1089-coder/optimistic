extends Node
class_name AICharacterSleepBehaviorModule

@export var needs_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterNeedsModule")
@export var need_planner_path: NodePath = NodePath("../AICharacterNeedsBundle/NeedDrivenAIPlanner")
@export var mood_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterMoodModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var sleep_need_id: StringName = CharacterNeedIds.ENERGY
@export var sleep_action_id: StringName = CharacterNeedActionIds.REST
@export var bedding_ids: Array[StringName] = [&"simple_mattress"]
@export var walk_speed: float = 80.0
@export var arrival_distance: float = 8.0
@export var bedding_sleep_start_distance: float = 48.0
@export var wake_ratio: float = 0.98
@export var energy_recovery_per_game_minute: float = 0.31
@export var pause_sleep_need_decay_while_sleeping: bool = true
@export var floor_sleep_energy_ratio: float = 0.01
@export var floor_sleep_mood_entry_path: String = "res://Data/Mood/Entries/rough_sleep.tres"
@export var stuck_check_enabled: bool = true
@export var stuck_timeout_seconds: float = 2.0
@export var stuck_position_epsilon: float = 1.0
@export var stuck_sleep_start_distance: float = 64.0
@export var stuck_reset_cooldown_seconds: float = 3.0

var _body: CharacterBody2D
var _needs_module: CharacterNeedsModule
var _need_planner: NeedDrivenAIPlanner
var _mood_module: CharacterMoodModule
var _furniture_root: Node
var _target_bedding: Node2D
var _floor_sleep_mood_entry: CharacterMoodEntryData
var _is_active := false
var _is_sleeping := false
var _is_floor_sleeping := false
var _sleep_need_was_disabled_by_sleep := false
var _facing_direction := Vector2.DOWN
var _last_walk_position := Vector2(INF, INF)
var _stuck_timer := 0.0
var _sleep_route_cooldown_timer := 0.0


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func is_active() -> bool:
	return _is_active


func is_sleeping() -> bool:
	return _is_sleeping


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	_is_active = false
	_sleep_route_cooldown_timer = maxf(_sleep_route_cooldown_timer - delta, 0.0)

	if _body == null or _needs_module == null:
		_stop_sleeping()
		return Vector2.ZERO

	if not _should_sleep_now():
		_stop_sleeping()
		return Vector2.ZERO

	if _is_sleeping:
		_is_active = true
		_recover_energy(delta)
		return Vector2.ZERO

	if _should_floor_sleep_now():
		_start_floor_sleep()
		_recover_energy(delta)
		return Vector2.ZERO

	if _sleep_route_cooldown_timer > 0.0:
		_is_active = true
		return Vector2.ZERO

	_target_bedding = _find_nearest_bedding()
	if _target_bedding == null:
		_stop_sleeping()
		return Vector2.ZERO

	_is_active = true
	var target_position := _get_bedding_sleep_position(_target_bedding)
	var to_target := target_position - _body.global_position
	var target_distance := to_target.length()

	if target_distance <= bedding_sleep_start_distance:
		_start_bedding_sleep()
		_recover_energy(delta)
		return Vector2.ZERO

	if _is_stuck_trying_to_reach_bedding(delta, target_distance):
		if target_distance <= stuck_sleep_start_distance:
			_start_bedding_sleep()
			_recover_energy(delta)
			return Vector2.ZERO
		_reset_sleep_attempt()
		return Vector2.ZERO

	if target_distance > arrival_distance:
		_facing_direction = to_target.normalized()
		return _facing_direction * walk_speed

	_start_bedding_sleep()
	_recover_energy(delta)
	return Vector2.ZERO


func _should_sleep_now() -> bool:
	var energy_ratio := _get_energy_ratio()
	if _is_sleeping:
		return energy_ratio < wake_ratio
	if _should_floor_sleep_now():
		return true
	if _need_planner == null:
		return false
	return _need_planner.get_next_action_id() == sleep_action_id


func _should_floor_sleep_now() -> bool:
	return _get_energy_ratio() <= floor_sleep_energy_ratio


func _start_bedding_sleep() -> void:
	_start_sleeping(false)


func _start_floor_sleep() -> void:
	_start_sleeping(true)
	_apply_floor_sleep_mood_entry()


func _start_sleeping(floor_sleeping: bool) -> void:
	_is_active = true
	_is_sleeping = true
	_is_floor_sleeping = floor_sleeping
	_target_bedding = null
	_facing_direction = Vector2.DOWN
	_reset_stuck_watch()
	_set_sleep_need_decay_enabled(false)


func _recover_energy(delta: float) -> void:
	if _needs_module == null:
		return
	var game_minutes := _get_game_minutes_from_delta(delta)
	if game_minutes <= 0.0:
		return
	_needs_module.add_need_value(sleep_need_id, energy_recovery_per_game_minute * game_minutes)


func _get_game_minutes_from_delta(delta: float) -> float:
	var game_clock := get_node_or_null("/root/GameClock")
	if game_clock != null and game_clock.has_method("get"):
		var seconds_per_minute := float(game_clock.get("real_seconds_per_game_minute"))
		if seconds_per_minute > 0.0:
			return delta / seconds_per_minute
	return delta


func _get_energy_ratio() -> float:
	if _needs_module == null:
		return 0.0
	return _needs_module.get_need_ratio(sleep_need_id, 0.0)


func _stop_sleeping() -> void:
	_set_sleep_need_decay_enabled(true)
	_is_active = false
	_is_sleeping = false
	_is_floor_sleeping = false
	_target_bedding = null
	_sleep_route_cooldown_timer = 0.0
	_reset_stuck_watch()


func _reset_sleep_attempt() -> void:
	_target_bedding = null
	_sleep_route_cooldown_timer = stuck_reset_cooldown_seconds
	_reset_stuck_watch()


func _is_stuck_trying_to_reach_bedding(delta: float, _target_distance: float) -> bool:
	if not stuck_check_enabled:
		return false
	if _body == null:
		return false
	if _last_walk_position.x == INF or _last_walk_position.y == INF:
		_last_walk_position = _body.global_position
		_stuck_timer = 0.0
		return false

	var moved_distance := _body.global_position.distance_to(_last_walk_position)
	if moved_distance > stuck_position_epsilon:
		_last_walk_position = _body.global_position
		_stuck_timer = 0.0
		return false

	_stuck_timer += delta
	return _stuck_timer >= stuck_timeout_seconds


func _reset_stuck_watch() -> void:
	_last_walk_position = Vector2(INF, INF)
	_stuck_timer = 0.0


func _apply_floor_sleep_mood_entry() -> void:
	if _mood_module == null:
		return
	if _floor_sleep_mood_entry == null:
		_floor_sleep_mood_entry = _load_floor_sleep_mood_entry()
	if _floor_sleep_mood_entry == null:
		return
	_mood_module.add_entry(_floor_sleep_mood_entry)


func _load_floor_sleep_mood_entry() -> CharacterMoodEntryData:
	if floor_sleep_mood_entry_path.is_empty():
		return null
	if not ResourceLoader.exists(floor_sleep_mood_entry_path):
		return null
	var resource := load(floor_sleep_mood_entry_path)
	if resource != null and resource is CharacterMoodEntryData:
		return resource as CharacterMoodEntryData
	return null


func _set_sleep_need_decay_enabled(enabled: bool) -> void:
	if not pause_sleep_need_decay_while_sleeping:
		return
	if _needs_module == null:
		return
	var sleep_need := _needs_module.get_need(sleep_need_id)
	if sleep_need == null:
		return

	if not enabled:
		if not sleep_need.enabled:
			return
		sleep_need.enabled = false
		_sleep_need_was_disabled_by_sleep = true
		return

	if _sleep_need_was_disabled_by_sleep:
		sleep_need.enabled = true
		_sleep_need_was_disabled_by_sleep = false


func _find_nearest_bedding() -> Node2D:
	if _furniture_root == null:
		return null

	var nearest: Node2D = null
	var nearest_distance := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_bedding(furniture):
			continue
		var distance := _body.global_position.distance_squared_to(_get_bedding_sleep_position(furniture))
		if nearest == null or distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
	return nearest


func _is_bedding(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("is_bedding") and furniture.call("is_bedding") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if bedding_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if bedding_ids.has(property_id):
			return true
	return false


func _get_bedding_sleep_position(bedding: Node2D) -> Vector2:
	if bedding == null:
		return Vector2.ZERO
	if bedding.has_method("get_sleep_target_global_position"):
		var target_position: Vector2 = bedding.call("get_sleep_target_global_position")
		return target_position
	return bedding.global_position


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as CharacterBody2D
	if _needs_module == null and not needs_module_path.is_empty():
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if _need_planner == null and not need_planner_path.is_empty():
		_need_planner = get_node_or_null(need_planner_path) as NeedDrivenAIPlanner
	if _mood_module == null and not mood_module_path.is_empty():
		_mood_module = get_node_or_null(mood_module_path) as CharacterMoodModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
