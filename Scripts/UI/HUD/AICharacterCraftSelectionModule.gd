extends Node
class_name AICharacterCraftSelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"

@export var craft_behavior_node_name: StringName = &"AICharacterCraftBehaviorModule"

var _craft_menu: Node
var _selection_context: Node
var _default_actor_path: NodePath


func _ready() -> void:
	_craft_menu = get_parent()
	if _craft_menu != null:
		_default_actor_path = _craft_menu.get("actor_path")
	_connect_selection_context()
	call_deferred("_connect_selection_context")


func _exit_tree() -> void:
	_disconnect_selection_context()


func _connect_selection_context() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var context := tree.get_first_node_in_group(SELECTION_CONTEXT_GROUP)
	if context == _selection_context:
		_apply_current_selection()
		return
	_disconnect_selection_context()
	_selection_context = context
	if _selection_context == null:
		return
	var callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and not _selection_context.is_connected(&"selected_actor_changed", callable):
		_selection_context.connect(&"selected_actor_changed", callable)
	_apply_current_selection()


func _disconnect_selection_context() -> void:
	if _selection_context == null or not is_instance_valid(_selection_context):
		_selection_context = null
		return
	var callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and _selection_context.is_connected(&"selected_actor_changed", callable):
		_selection_context.disconnect(&"selected_actor_changed", callable)
	_selection_context = null


func _apply_current_selection() -> void:
	if _selection_context == null or not _selection_context.has_method("get_selected_actor"):
		return
	_on_selected_actor_changed(_selection_context.call("get_selected_actor") as Node)


func _on_selected_actor_changed(actor: Node) -> void:
	if _craft_menu == null or not is_instance_valid(_craft_menu):
		return
	if not _has_craft_request_target(actor):
		_craft_menu.set("actor_path", _default_actor_path)
		return
	_craft_menu.set("actor_path", _craft_menu.get_path_to(actor))


func _has_craft_request_target(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.has_method("request_craft"):
		return true
	var behavior := actor.get_node_or_null(NodePath(String(craft_behavior_node_name)))
	return behavior != null and behavior.has_method("request_craft")
