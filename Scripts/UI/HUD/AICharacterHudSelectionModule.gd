extends Node
class_name AICharacterHudSelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"

var _hud: Node
var _selection_context: Node


func _ready() -> void:
	_hud = get_parent()
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
		return
	_disconnect_selection_context()
	_selection_context = context
	if _selection_context == null:
		return
	var request_callable := Callable(self, "_on_selection_requested")
	if _selection_context.has_signal(&"selection_requested") and not _selection_context.is_connected(&"selection_requested", request_callable):
		_selection_context.connect(&"selection_requested", request_callable)
	var changed_callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and not _selection_context.is_connected(&"selected_actor_changed", changed_callable):
		_selection_context.connect(&"selected_actor_changed", changed_callable)


func _disconnect_selection_context() -> void:
	if _selection_context == null or not is_instance_valid(_selection_context):
		_selection_context = null
		return
	var request_callable := Callable(self, "_on_selection_requested")
	if _selection_context.has_signal(&"selection_requested") and _selection_context.is_connected(&"selection_requested", request_callable):
		_selection_context.disconnect(&"selection_requested", request_callable)
	var changed_callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and _selection_context.is_connected(&"selected_actor_changed", changed_callable):
		_selection_context.disconnect(&"selected_actor_changed", changed_callable)
	_selection_context = null


func _on_selection_requested(actor: Node) -> void:
	if actor == null or _hud == null or not is_instance_valid(_hud):
		return
	if _is_build_mode_enabled():
		return
	if _hud.has_method("toggle_actor"):
		_hud.call("toggle_actor", actor)


func _on_selected_actor_changed(actor: Node) -> void:
	if actor != null or _hud == null or not is_instance_valid(_hud):
		return
	if _hud.has_method("clear_actor"):
		_hud.call("clear_actor")


func _is_build_mode_enabled() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var controller := tree.get_first_node_in_group(&"build_mode_controller")
	if controller == null or not controller.has_method("is_build_mode_enabled"):
		return false
	return controller.call("is_build_mode_enabled") == true
