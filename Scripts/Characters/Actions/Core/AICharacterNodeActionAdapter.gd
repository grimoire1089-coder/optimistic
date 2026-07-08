extends AICharacterActionPackage
class_name AICharacterNodeActionAdapter

@export var action_node_path: NodePath = NodePath("")
@export var base_score: float = 0.0
@export var can_start_method: StringName = &""
@export var score_method: StringName = &""
@export var start_method: StringName = &""
@export var tick_method: StringName = &"get_velocity"
@export var tick_pass_delta: bool = true
@export var active_check_method: StringName = &"is_active"
@export var complete_when_inactive: bool = true
@export var cancel_method_names: PackedStringArray = PackedStringArray()
@export var cleanup_method_names: PackedStringArray = PackedStringArray()
@export var debug_summary_method: StringName = &"get_debug_movement_summary"
@export var progress_visible_method: StringName = &"is_action_progress_visible"
@export var progress_ratio_method: StringName = &"get_action_progress_ratio"
@export var item_visible_method: StringName = &"is_action_item_display_visible"
@export var item_icon_method: StringName = &"get_action_item_icon_path"

var _action_node: Node


func bind(actor: Node) -> void:
	super.bind(actor)
	_action_node = null


func unbind() -> void:
	cleanup()
	_action_node = null
	super.unbind()


func can_start(context: AICharacterActionContext) -> bool:
	var node := _resolve_action_node(context)
	if node == null:
		return false
	if can_start_method == &"":
		return true
	if not node.has_method(can_start_method):
		return false
	return bool(node.call(can_start_method))


func get_score(context: AICharacterActionContext) -> float:
	var node := _resolve_action_node(context)
	if node == null:
		return -INF
	if score_method == &"":
		return base_score
	if not node.has_method(score_method):
		return base_score
	return float(node.call(score_method))


func start(context: AICharacterActionContext) -> bool:
	var node := _resolve_action_node(context)
	if node == null:
		return false
	if start_method == &"":
		return true
	if not node.has_method(start_method):
		return false
	return bool(node.call(start_method))


func tick(context: AICharacterActionContext, delta: float) -> AICharacterActionResult:
	var node := _resolve_action_node(context)
	if node == null:
		return AICharacterActionResult.failed("missing action node: %s" % str(action_node_path))
	if tick_method == &"" or not node.has_method(tick_method):
		return AICharacterActionResult.running()

	var tick_value: Variant
	if tick_pass_delta:
		tick_value = node.call(tick_method, delta)
	else:
		tick_value = node.call(tick_method)

	if tick_value is AICharacterActionResult:
		return tick_value as AICharacterActionResult

	if tick_value is Vector2:
		var velocity := tick_value as Vector2
		if complete_when_inactive and not _is_node_active(node):
			return AICharacterActionResult.completed()
		return AICharacterActionResult.moving(velocity, _get_facing_direction(node))

	if tick_value is bool:
		return AICharacterActionResult.running() if bool(tick_value) else AICharacterActionResult.completed()

	if complete_when_inactive and not _is_node_active(node):
		return AICharacterActionResult.completed()
	return AICharacterActionResult.running()


func cancel(context: AICharacterActionContext = null) -> void:
	var node := _resolve_action_node(context)
	if node == null:
		return
	_call_first_available(node, cancel_method_names)


func cleanup(context: AICharacterActionContext = null) -> void:
	var node := _resolve_action_node(context)
	if node == null:
		return
	_call_all_available(node, cleanup_method_names)


func get_debug_summary() -> String:
	var node := _resolve_cached_action_node()
	if node != null and debug_summary_method != &"" and node.has_method(debug_summary_method):
		return String(node.call(debug_summary_method))
	return "adapter node=%s active=%s" % [str(action_node_path), str(_is_node_active(node))]


func is_progress_visible() -> bool:
	var node := _resolve_cached_action_node()
	if node == null or progress_visible_method == &"" or not node.has_method(progress_visible_method):
		return false
	return bool(node.call(progress_visible_method))


func get_progress_ratio() -> float:
	var node := _resolve_cached_action_node()
	if node == null or progress_ratio_method == &"" or not node.has_method(progress_ratio_method):
		return 0.0
	return clampf(float(node.call(progress_ratio_method)), 0.0, 1.0)


func is_item_display_visible() -> bool:
	var node := _resolve_cached_action_node()
	if node == null or item_visible_method == &"" or not node.has_method(item_visible_method):
		return false
	return bool(node.call(item_visible_method))


func get_item_icon_path() -> String:
	var node := _resolve_cached_action_node()
	if node == null or item_icon_method == &"" or not node.has_method(item_icon_method):
		return ""
	return String(node.call(item_icon_method))


func _resolve_action_node(context: AICharacterActionContext = null) -> Node:
	if _action_node != null and is_instance_valid(_action_node):
		return _action_node
	var actor := _actor
	if actor == null and context != null:
		actor = context.actor
	if actor == null or not is_instance_valid(actor) or action_node_path.is_empty():
		return null
	_action_node = actor.get_node_or_null(action_node_path)
	return _action_node


func _resolve_cached_action_node() -> Node:
	if _action_node != null and is_instance_valid(_action_node):
		return _action_node
	return _resolve_action_node()


func _is_node_active(node: Node) -> bool:
	if node == null:
		return false
	if active_check_method == &"":
		return true
	if not node.has_method(active_check_method):
		return true
	return bool(node.call(active_check_method))


func _get_facing_direction(node: Node) -> Vector2:
	if node == null or not node.has_method("get_facing_direction"):
		return Vector2.ZERO
	var value: Variant = node.call("get_facing_direction")
	if value is Vector2:
		return value
	return Vector2.ZERO


func _call_first_available(node: Node, method_names: PackedStringArray) -> bool:
	if node == null:
		return false
	for method_name in method_names:
		var method := StringName(method_name)
		if method == &"" or not node.has_method(method):
			continue
		node.call(method)
		return true
	return false


func _call_all_available(node: Node, method_names: PackedStringArray) -> void:
	if node == null:
		return
	for method_name in method_names:
		var method := StringName(method_name)
		if method == &"" or not node.has_method(method):
			continue
		node.call(method)
