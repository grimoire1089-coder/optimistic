extends Node
class_name MainSceneSleepFastForwardModule

@export var actor_paths: Array[NodePath] = [NodePath("../Robin")]
@export var ai_character_actor_group: StringName = &"ai_character_actor"
@export var map_travel_module_path: NodePath = NodePath("../MainSceneMapTravelModule")
@export var build_mode_controller_path: NodePath = NodePath("../BuildModeController")
@export var time_scale_controller_path: NodePath = NodePath("/root/TimeScaleController")
@export var pause_during_build_mode: bool = true

var _map_travel_module: Node
var _build_mode_controller: Node
var _time_scale_controller: Node


func _ready() -> void:
	_resolve_refs()
	_sync_sleep_fast_forward()


func _process(_delta: float) -> void:
	_resolve_refs()
	_sync_sleep_fast_forward()


func _exit_tree() -> void:
	if _time_scale_controller != null and _time_scale_controller.has_method("set_sleep_fast_forward"):
		_time_scale_controller.call("set_sleep_fast_forward", false)


func _sync_sleep_fast_forward() -> void:
	if _time_scale_controller == null:
		return

	var actors: Array[Node] = _get_ai_characters_on_active_map()
	var map_ai_count: int = actors.size()
	var sleeping_ai_count: int = _get_sleeping_ai_count(actors)
	var can_fast_forward: bool = _can_fast_forward()

	if _time_scale_controller.has_method("update_sleep_fast_forward"):
		_time_scale_controller.call("update_sleep_fast_forward", map_ai_count, sleeping_ai_count, can_fast_forward)
		return

	if _time_scale_controller.has_method("set_sleep_fast_forward"):
		_time_scale_controller.call("set_sleep_fast_forward", can_fast_forward and map_ai_count == 1 and sleeping_ai_count == 1)


func _get_ai_characters_on_active_map() -> Array[Node]:
	var actors: Array[Node] = []
	var seen_instance_ids: Dictionary = {}
	var active_map_id: StringName = _get_active_map_id()

	for actor_path in actor_paths:
		var actor_from_path: Node = get_node_or_null(actor_path)
		_add_actor_if_countable(actors, seen_instance_ids, actor_from_path, active_map_id)

	for group_item in get_tree().get_nodes_in_group(ai_character_actor_group):
		var actor_from_group: Node = group_item as Node
		_add_actor_if_countable(actors, seen_instance_ids, actor_from_group, active_map_id)

	return actors


func _add_actor_if_countable(actors: Array[Node], seen_instance_ids: Dictionary, actor: Node, active_map_id: StringName) -> void:
	if actor == null:
		return
	if not is_instance_valid(actor):
		return
	if not actor.is_inside_tree():
		return
	if actor is CanvasItem:
		var canvas_item: CanvasItem = actor as CanvasItem
		if not canvas_item.is_visible_in_tree():
			return
	if not _is_actor_on_active_map(actor, active_map_id):
		return

	var instance_id: int = actor.get_instance_id()
	if seen_instance_ids.has(instance_id):
		return

	seen_instance_ids[instance_id] = true
	actors.append(actor)


func _get_sleeping_ai_count(actors: Array[Node]) -> int:
	var count: int = 0
	for actor in actors:
		if actor == null:
			continue
		if actor.has_method("is_sleeping") and actor.call("is_sleeping") == true:
			count += 1
	return count


func _is_actor_on_active_map(actor: Node, active_map_id: StringName) -> bool:
	if active_map_id == &"":
		return true

	var actor_map_id: StringName = _get_actor_map_id(actor)
	if actor_map_id == &"":
		return true

	return actor_map_id == active_map_id


func _get_actor_map_id(actor: Node) -> StringName:
	if actor == null:
		return &""
	if actor.has_method("get_current_map_id"):
		var method_value: Variant = actor.call("get_current_map_id")
		return StringName(str(method_value))
	if actor.has_meta("current_map_id"):
		var meta_value: Variant = actor.get_meta("current_map_id", &"")
		return StringName(str(meta_value))
	return &""


func _get_active_map_id() -> StringName:
	if _map_travel_module == null:
		return &""
	if not _map_travel_module.has_method("get_active_map_id"):
		return &""
	var value: Variant = _map_travel_module.call("get_active_map_id")
	return StringName(str(value))


func _can_fast_forward() -> bool:
	if pause_during_build_mode and _is_build_mode_enabled():
		return false
	return true


func _is_build_mode_enabled() -> bool:
	if _build_mode_controller == null:
		return false
	if not _build_mode_controller.has_method("is_build_mode_enabled"):
		return false
	return _build_mode_controller.call("is_build_mode_enabled") == true


func _resolve_refs() -> void:
	if _time_scale_controller == null and not time_scale_controller_path.is_empty():
		_time_scale_controller = get_node_or_null(time_scale_controller_path)
	if _map_travel_module == null and not map_travel_module_path.is_empty():
		_map_travel_module = get_node_or_null(map_travel_module_path)
	if _build_mode_controller == null and not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path)
	if _build_mode_controller == null:
		_build_mode_controller = get_tree().get_first_node_in_group(&"build_mode_controller")
