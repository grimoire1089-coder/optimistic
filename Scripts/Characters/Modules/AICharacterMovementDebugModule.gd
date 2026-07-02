extends Node
class_name AICharacterMovementDebugModule

@export var enabled: bool = true
@export var body_path: NodePath = NodePath("..")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var hydrate_behavior_path: NodePath = NodePath("../AICharacterHydrateBehaviorModule")
@export var sleep_behavior_path: NodePath = NodePath("../AICharacterSleepBehaviorModule")
@export var craft_behavior_path: NodePath = NodePath("../AICharacterCraftBehaviorModule")
@export var entrance_travel_behavior_path: NodePath = NodePath("../AICharacterEntranceTravelBehaviorModule")
@export var normal_log_interval_seconds: float = 3.0
@export var stuck_log_seconds: float = 1.0
@export var stuck_position_epsilon: float = 1.0
@export var nearby_furniture_radius: float = 96.0
@export var log_slide_collisions: bool = true
@export var log_action_changes: bool = true
@export var log_active_heartbeat: bool = true
@export var collapse_repeated_messages: bool = true
@export_range(2, 100, 1) var repeated_message_report_interval: int = 10

var _body: CharacterBody2D
var _room_map: RoomMapGridModule
var _furniture_root: Node
var _hydrate_behavior: Node
var _sleep_behavior: Node
var _craft_behavior: Node
var _entrance_travel_behavior: Node

var _last_action: StringName = &""
var _last_position: Vector2 = Vector2(INF, INF)
var _stuck_timer: float = 0.0
var _normal_log_timer: float = 0.0
var _last_collision_text: String = ""
var _last_emitted_debug_message: String = ""
var _last_emitted_repeat_count: int = 0


func _ready() -> void:
	_resolve_refs()
	_emit_debug("debug module ready")


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_resolve_refs()
	if _body == null:
		return

	var action: StringName = _get_action_id()
	var is_active: bool = action != &"idle"

	if log_action_changes and action != _last_action:
		_emit_debug(_make_state_message("action_changed", action))
		_last_action = action
		_reset_stuck_watch()

	if is_active:
		_update_stuck_watch(delta, action)
		_update_heartbeat(delta, action)
	else:
		_reset_stuck_watch()
		_normal_log_timer = 0.0

	if log_slide_collisions:
		_log_slide_collision_if_changed(action)


func _update_heartbeat(delta: float, action: StringName) -> void:
	if not log_active_heartbeat:
		return
	_normal_log_timer += maxf(delta, 0.0)
	if _normal_log_timer < normal_log_interval_seconds:
		return
	_normal_log_timer = 0.0
	_emit_debug(_make_state_message("active", action))


func _update_stuck_watch(delta: float, action: StringName) -> void:
	if _last_position.x == INF or _last_position.y == INF:
		_last_position = _body.global_position
		_stuck_timer = 0.0
		return

	var moved_distance: float = _body.global_position.distance_to(_last_position)
	if moved_distance > stuck_position_epsilon:
		_last_position = _body.global_position
		_stuck_timer = 0.0
		return

	_stuck_timer += maxf(delta, 0.0)
	if _stuck_timer >= stuck_log_seconds:
		_stuck_timer = 0.0
		_emit_debug(_make_state_message("stuck", action))


func _reset_stuck_watch() -> void:
	_last_position = Vector2(INF, INF)
	_stuck_timer = 0.0


func _log_slide_collision_if_changed(action: StringName) -> void:
	var collision_count: int = _body.get_slide_collision_count()
	if collision_count <= 0:
		if not _last_collision_text.is_empty():
			_last_collision_text = ""
		return

	var parts: PackedStringArray = []
	for index in range(collision_count):
		var collision: KinematicCollision2D = _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		var collider_name: String = "unknown"
		if collider != null and collider is Node:
			collider_name = (collider as Node).name
		parts.append("%s normal=%s" % [collider_name, _format_vec2(collision.get_normal())])

	var collision_text: String = "; ".join(parts)
	if collision_text == _last_collision_text:
		return
	_last_collision_text = collision_text
	_emit_debug("slide_collision action=%s %s" % [String(action), collision_text])


func _make_state_message(reason: String, action: StringName) -> String:
	var grid_cell: Vector2i = _get_body_grid_cell()
	var target_text: String = _get_target_text(action)
	var path_size: int = _get_path_size(action)
	var nearest_furniture_text: String = _get_nearest_furniture_text()
	var active_flags: String = _get_active_behavior_flags()
	return "%s action=%s active=%s pos=%s grid=%s vel=%s target=%s path=%d near=%s" % [
		reason,
		String(action),
		active_flags,
		_format_vec2(_body.global_position),
		_format_vec2i(grid_cell),
		_format_vec2(_body.velocity),
		target_text,
		path_size,
		nearest_furniture_text,
	]


func _get_action_id() -> StringName:
	# NeedPlannerの次行動ではなく、実際に動いている行動モジュールを優先して見る。
	# HUD上の表示ズレや、複数モジュールが同時にactiveになった時の切り分けに使う。
	if _entrance_travel_behavior != null and _entrance_travel_behavior.has_method("is_active") and _entrance_travel_behavior.call("is_active") == true:
		return &"map_travel"
	if _craft_behavior != null and _craft_behavior.has_method("is_active") and _craft_behavior.call("is_active") == true:
		return &"crafting"
	if _hydrate_behavior != null and _hydrate_behavior.has_method("is_active") and _hydrate_behavior.call("is_active") == true:
		return &"hydrating"
	if _sleep_behavior != null and _sleep_behavior.has_method("is_active") and _sleep_behavior.call("is_active") == true:
		return &"sleeping"
	return &"idle"


func _get_active_behavior_flags() -> String:
	var flags: PackedStringArray = []
	flags.append("hydrate=%s" % _is_behavior_active(_hydrate_behavior))
	flags.append("sleep=%s" % _is_behavior_active(_sleep_behavior))
	flags.append("craft=%s" % _is_behavior_active(_craft_behavior))
	flags.append("travel=%s" % _is_behavior_active(_entrance_travel_behavior))
	return ",".join(flags)


func _is_behavior_active(behavior: Node) -> bool:
	if behavior == null:
		return false
	if not behavior.has_method("is_active"):
		return false
	return behavior.call("is_active") == true


func _get_target_text(action: StringName) -> String:
	var behavior: Node = _get_behavior_for_action(action)
	if behavior == null:
		return "none"

	var target: Object = null
	if String(action) == "hydrating" or String(action) == "hydrate":
		target = behavior.get("_target_kitchen")
	elif String(action) == "sleeping" or String(action) == "sleep":
		target = behavior.get("_target_bedding")
	elif String(action) == "crafting" or String(action) == "craft":
		target = behavior.get("_target_furniture")

	if target != null and target is Node2D:
		var target_node: Node2D = target as Node2D
		return "%s@%s grid=%s" % [target_node.name, _format_vec2(target_node.global_position), _get_furniture_grid_text(target_node)]

	return "none"


func _get_path_size(action: StringName) -> int:
	var behavior: Node = _get_behavior_for_action(action)
	if behavior == null:
		return 0
	var path_value: Variant = behavior.get("_path_cells")
	if path_value is Array:
		return (path_value as Array).size()
	return 0


func _get_behavior_for_action(action: StringName) -> Node:
	var action_text: String = String(action)
	if action_text == "hydrating" or action_text == "hydrate":
		return _hydrate_behavior
	if action_text == "sleeping" or action_text == "sleep":
		return _sleep_behavior
	if action_text == "crafting" or action_text == "craft":
		return _craft_behavior
	if action_text == "map_travel":
		return _entrance_travel_behavior
	return null


func _get_body_grid_cell() -> Vector2i:
	if _room_map == null or _body == null:
		return Vector2i(-999999, -999999)
	return _room_map.world_to_grid(_body.global_position)


func _get_nearest_furniture_text() -> String:
	if _furniture_root == null or _body == null:
		return "none"
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for child in _furniture_root.get_children():
		var furniture: Node2D = child as Node2D
		if furniture == null:
			continue
		var distance: float = _body.global_position.distance_to(furniture.global_position)
		if distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
	if nearest == null or nearest_distance > nearby_furniture_radius:
		return "none"
	return "%s dist=%.1f grid=%s" % [nearest.name, nearest_distance, _get_furniture_grid_text(nearest)]


func _get_furniture_grid_text(furniture: Node) -> String:
	if furniture == null:
		return "?"
	var grid_position: Variant = furniture.get_meta("grid_position", Vector2i(-999999, -999999))
	var grid_footprint: Variant = furniture.get_meta("grid_footprint", Vector2i(1, 1))
	return "%s/%s" % [str(grid_position), str(grid_footprint)]


func _emit_debug(message: String) -> void:
	if collapse_repeated_messages and message == _last_emitted_debug_message:
		_last_emitted_repeat_count += 1
		if _last_emitted_repeat_count % maxi(repeated_message_report_interval, 2) == 0:
			_emit_debug_raw("%s repeated=%d" % [message, _last_emitted_repeat_count + 1])
		return

	if collapse_repeated_messages and _last_emitted_repeat_count > 0:
		_emit_debug_raw("previous repeated=%d %s" % [_last_emitted_repeat_count + 1, _last_emitted_debug_message])

	_last_emitted_debug_message = message
	_last_emitted_repeat_count = 0
	_emit_debug_raw(message)


func _emit_debug_raw(message: String) -> void:
	var text: String = "[AI Move] %s" % message
	var log_node: Node = get_tree().get_first_node_in_group(&"message_log")
	if log_node != null and log_node.has_method("add_debug_message"):
		log_node.call("add_debug_message", text)
	else:
		print(text)


func _format_vec2(value: Vector2) -> String:
	return "(%.1f, %.1f)" % [value.x, value.y]


func _format_vec2i(value: Vector2i) -> String:
	return "(%d, %d)" % [value.x, value.y]


func _resolve_refs() -> void:
	if _body == null and not body_path.is_empty():
		_body = get_node_or_null(body_path) as CharacterBody2D
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _hydrate_behavior == null and not hydrate_behavior_path.is_empty():
		_hydrate_behavior = get_node_or_null(hydrate_behavior_path)
	if _sleep_behavior == null and not sleep_behavior_path.is_empty():
		_sleep_behavior = get_node_or_null(sleep_behavior_path)
	if _craft_behavior == null and not craft_behavior_path.is_empty():
		_craft_behavior = get_node_or_null(craft_behavior_path)
	if _entrance_travel_behavior == null and not entrance_travel_behavior_path.is_empty():
		_entrance_travel_behavior = get_node_or_null(entrance_travel_behavior_path)
