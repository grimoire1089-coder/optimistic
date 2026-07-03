extends Node
class_name AICharacterMovementDebugModule

const INVALID_DEBUG_GRID_POSITION := Vector2i(-999999, -999999)

@export var enabled: bool = true
@export var body_path: NodePath = NodePath("..")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var hydrate_behavior_path: NodePath = NodePath("../AICharacterHydrateBehaviorModule")
@export var hygiene_behavior_path: NodePath = NodePath("../AICharacterHygieneBehaviorModule")
@export var sleep_behavior_path: NodePath = NodePath("../AICharacterSleepBehaviorModule")
@export var sit_behavior_path: NodePath = NodePath("../AICharacterSitBehaviorModule")
@export var craft_behavior_path: NodePath = NodePath("../AICharacterCraftBehaviorModule")
@export var read_book_behavior_path: NodePath = NodePath("../AICharacterReadBookBehaviorModule")
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
var _hygiene_behavior: Node
var _sleep_behavior: Node
var _sit_behavior: Node
var _craft_behavior: Node
var _read_book_behavior: Node
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
	var should_watch_movement: bool = _should_watch_movement_for_action(action)

	if log_action_changes and action != _last_action:
		_emit_debug(_make_state_message("action_changed", action))
		_last_action = action
		_reset_stuck_watch()

	if is_active and should_watch_movement:
		_update_stuck_watch(delta, action)
		_update_heartbeat(delta, action)
	else:
		_reset_stuck_watch()
		_normal_log_timer = 0.0

	if log_slide_collisions and should_watch_movement:
		_log_slide_collision_if_changed(action)


func _should_watch_movement_for_action(action: StringName) -> bool:
	if action == &"hydrating" and _hydrate_behavior != null:
		if _hydrate_behavior.has_method("is_drinking") and _hydrate_behavior.call("is_drinking") == true:
			return false
	if action == &"maintaining" and _hygiene_behavior != null:
		if _hygiene_behavior.has_method("is_showering") and _hygiene_behavior.call("is_showering") == true:
			return false
	if action == &"crafting" and _craft_behavior != null:
		if _has_property(_craft_behavior, &"_is_crafting") and _craft_behavior.get("_is_crafting") == true:
			return false
	if action != &"sleeping":
		if action == &"reading_book" and _read_book_behavior != null:
			if _read_book_behavior.has_method("is_reading") and _read_book_behavior.call("is_reading") == true:
				return false
		if action == &"sitting" and _sit_behavior != null:
			if _sit_behavior.has_method("is_using_lapis") and _sit_behavior.call("is_using_lapis") == true:
				return false
			if _sit_behavior.has_method("is_sitting") and _sit_behavior.call("is_sitting") == true:
				return false
		return true
	if _sleep_behavior != null and _sleep_behavior.has_method("is_sleeping") and _sleep_behavior.call("is_sleeping") == true:
		return false
	return true


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
	var movement_plan_text: String = _get_movement_plan_text(action)
	var cell_size_text := _get_cell_size_text()
	var screen_cell_size_text := _get_screen_cell_size_text()
	return "%s action=%s active=%s pos=%s grid=%s cell=%s screen_cell=%s vel=%s target=%s path=%d plan=%s near=%s" % [
		reason,
		String(action),
		active_flags,
		_format_vec2(_body.global_position),
		_format_vec2i(grid_cell),
		cell_size_text,
		screen_cell_size_text,
		_format_vec2(_body.velocity),
		target_text,
		path_size,
		movement_plan_text,
		nearest_furniture_text,
	]


func _get_movement_plan_text(action: StringName) -> String:
	var behavior: Node = _get_behavior_for_action(action)
	if behavior == null:
		return "none"
	if behavior.has_method("get_debug_movement_summary"):
		return str(behavior.call("get_debug_movement_summary"))

	var path_cells := _get_behavior_path_cells(behavior)
	var target_cell := _get_behavior_target_cell(behavior, path_cells)
	var next_cell := INVALID_DEBUG_GRID_POSITION
	if not path_cells.is_empty():
		next_cell = path_cells[0]
	var footprint := _get_behavior_footprint(behavior)
	if path_cells.is_empty() and not _is_valid_debug_cell(target_cell):
		return "none"
	return "target_cell=%s next_cell=%s path=%d footprint=%s" % [
		str(target_cell),
		str(next_cell),
		path_cells.size(),
		str(footprint),
	]


func _get_cell_size_text() -> String:
	if _room_map == null:
		return "none"
	return _format_vec2(_room_map.get_cell_size())


func _get_screen_cell_size_text() -> String:
	if _room_map == null:
		return "none"
	if _room_map.has_method("get_screen_cell_size"):
		var screen_cell_size: Vector2 = _room_map.call("get_screen_cell_size")
		return _format_vec2(screen_cell_size)
	return _format_vec2(_room_map.get_cell_size())


func _get_behavior_path_cells(behavior: Node) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if behavior == null or not _has_property(behavior, &"_path_cells"):
		return result
	var path_value: Variant = behavior.get("_path_cells")
	if not (path_value is Array):
		return result
	for cell_value in path_value:
		if cell_value is Vector2i:
			result.append(cell_value)
	return result


func _get_behavior_target_cell(behavior: Node, path_cells: Array[Vector2i]) -> Vector2i:
	for property_name in [&"_path_target_cell", &"_target_cell"]:
		if _has_property(behavior, property_name):
			var property_value: Variant = behavior.get(property_name)
			if property_value is Vector2i:
				return property_value
	var target_from_object := _get_behavior_target_cell_from_target_object(behavior)
	if _is_valid_debug_cell(target_from_object):
		return target_from_object
	if not path_cells.is_empty():
		return path_cells[path_cells.size() - 1]
	return INVALID_DEBUG_GRID_POSITION


func _get_behavior_target_cell_from_target_object(behavior: Node) -> Vector2i:
	for property_name in [&"_target_bedding", &"_target_kitchen", &"_target_shower", &"_target_stool", &"_target_furniture", &"_target_entrance"]:
		if not _has_property(behavior, property_name):
			continue
		var target_value: Variant = behavior.get(property_name)
		if not (target_value is Node2D):
			continue
		for method_name in [&"_get_bedding_side_sleep_cell", &"_get_kitchen_use_cell", &"_get_shower_use_cell", &"_get_stool_use_cell", &"_get_furniture_use_cell", &"_get_entrance_use_cell"]:
			if not behavior.has_method(method_name):
				continue
			var cell_value: Variant = behavior.call(method_name, target_value)
			if cell_value is Vector2i:
				return cell_value
	return INVALID_DEBUG_GRID_POSITION


func _get_behavior_footprint(behavior: Node) -> Vector2i:
	if behavior != null and _has_property(behavior, &"actor_grid_footprint"):
		var footprint_value: Variant = behavior.get("actor_grid_footprint")
		if footprint_value is Vector2i:
			return Vector2i(maxi(footprint_value.x, 1), maxi(footprint_value.y, 1))
	return Vector2i(1, 1)


func _is_valid_debug_cell(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_DEBUG_GRID_POSITION


func _get_action_id() -> StringName:
	# NeedPlannerの次行動ではなく、実際に動いている行動モジュールを優先して見る。
	# HUD上の表示ズレや、複数モジュールが同時にactiveになった時の切り分けに使う。
	if _entrance_travel_behavior != null and _entrance_travel_behavior.has_method("is_active") and _entrance_travel_behavior.call("is_active") == true:
		return &"map_travel"
	if _craft_behavior != null and _craft_behavior.has_method("is_active") and _craft_behavior.call("is_active") == true:
		return &"crafting"
	if _hydrate_behavior != null and _hydrate_behavior.has_method("is_active") and _hydrate_behavior.call("is_active") == true:
		return &"hydrating"
	if _hygiene_behavior != null and _hygiene_behavior.has_method("is_active") and _hygiene_behavior.call("is_active") == true:
		return &"maintaining"
	if _read_book_behavior != null and _read_book_behavior.has_method("is_active") and _read_book_behavior.call("is_active") == true:
		return &"reading_book"
	if _sit_behavior != null and _sit_behavior.has_method("is_active") and _sit_behavior.call("is_active") == true:
		return &"sitting"
	if _sleep_behavior != null and _sleep_behavior.has_method("is_active") and _sleep_behavior.call("is_active") == true:
		return &"sleeping"
	return &"idle"


func _get_active_behavior_flags() -> String:
	var flags: PackedStringArray = []
	flags.append("hydrate=%s" % _is_behavior_active(_hydrate_behavior))
	flags.append("hygiene=%s" % _is_behavior_active(_hygiene_behavior))
	flags.append("read=%s" % _is_behavior_active(_read_book_behavior))
	flags.append("sit=%s" % _is_behavior_active(_sit_behavior))
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
	elif String(action) == "maintaining" or String(action) == "hygiene" or String(action) == "showering":
		target = behavior.get("_target_shower")
	elif String(action) == "sitting" or String(action) == "sit":
		target = behavior.get("_target_stool")
	elif String(action) == "reading_book" or String(action) == "reading":
		target = behavior.get("_target_stool")
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
	if action_text == "maintaining" or action_text == "hygiene" or action_text == "showering":
		return _hygiene_behavior
	if action_text == "sitting" or action_text == "sit":
		return _sit_behavior
	if action_text == "reading_book" or action_text == "reading":
		return _read_book_behavior
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
	if _body == null and not body_path.is_empty():
		_body = get_node_or_null(body_path) as CharacterBody2D
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _hydrate_behavior == null and not hydrate_behavior_path.is_empty():
		_hydrate_behavior = get_node_or_null(hydrate_behavior_path)
	if _hygiene_behavior == null and not hygiene_behavior_path.is_empty():
		_hygiene_behavior = get_node_or_null(hygiene_behavior_path)
	if _sleep_behavior == null and not sleep_behavior_path.is_empty():
		_sleep_behavior = get_node_or_null(sleep_behavior_path)
	if _sit_behavior == null and not sit_behavior_path.is_empty():
		_sit_behavior = get_node_or_null(sit_behavior_path)
	if _craft_behavior == null and not craft_behavior_path.is_empty():
		_craft_behavior = get_node_or_null(craft_behavior_path)
	if _read_book_behavior == null and not read_book_behavior_path.is_empty():
		_read_book_behavior = get_node_or_null(read_book_behavior_path)
	if _entrance_travel_behavior == null and not entrance_travel_behavior_path.is_empty():
		_entrance_travel_behavior = get_node_or_null(entrance_travel_behavior_path)
