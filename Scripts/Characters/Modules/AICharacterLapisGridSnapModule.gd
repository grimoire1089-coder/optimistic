extends Node
class_name AICharacterLapisGridSnapModule

@export var actor_path: NodePath = NodePath("..")
@export var sit_behavior_path: NodePath = NodePath("../AICharacterSitBehaviorModule")
@export var enabled: bool = true
@export var snap_on_start: bool = true
@export var snap_on_finish: bool = true
@export var debug_log_enabled: bool = true

var _actor: Node
var _sit_behavior: AICharacterSitBehaviorModule
var _was_standing_lapis := false


func _ready() -> void:
	_resolve_refs()
	_was_standing_lapis = _is_standing_lapis_active()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	_resolve_refs()
	var is_standing_lapis := _is_standing_lapis_active()
	if is_standing_lapis and not _was_standing_lapis:
		if snap_on_start:
			_snap_actor_to_grid("start")
	elif not is_standing_lapis and _was_standing_lapis:
		if snap_on_finish:
			_snap_actor_to_grid("finish")
	_was_standing_lapis = is_standing_lapis


func _is_standing_lapis_active() -> bool:
	if _sit_behavior == null:
		return false
	if not _sit_behavior.has_method("is_using_lapis"):
		return false
	if not _sit_behavior.call("is_using_lapis") == true:
		return false
	if _sit_behavior.has_method("is_sitting") and _sit_behavior.call("is_sitting") == true:
		return false
	return true


func _snap_actor_to_grid(reason: String) -> void:
	if _actor == null:
		return
	if not _actor.has_method("snap_to_nearest_walkable_grid"):
		return
	var snapped := bool(_actor.call("snap_to_nearest_walkable_grid"))
	if debug_log_enabled and snapped:
		_push_debug("[AI Lapis] grid snap %s" % reason)


func _push_debug(message: String) -> void:
	var tree := get_tree()
	if tree == null:
		print(message)
		return
	var log_node := tree.get_first_node_in_group(&"message_log")
	if log_node != null and log_node.has_method("add_debug_message"):
		log_node.call("add_debug_message", message)
	else:
		print(message)


func _resolve_refs() -> void:
	if (_actor == null or not is_instance_valid(_actor)) and not actor_path.is_empty():
		_actor = get_node_or_null(actor_path)
	if (_sit_behavior == null or not is_instance_valid(_sit_behavior)) and not sit_behavior_path.is_empty():
		_sit_behavior = get_node_or_null(sit_behavior_path) as AICharacterSitBehaviorModule
