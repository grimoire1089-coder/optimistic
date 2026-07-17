extends Node
class_name AICharacterWorkSelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"

var _work_menu: Node
var _selection_context: Node
var _default_worker_path: NodePath


func _ready() -> void:
	_work_menu = get_parent()
	if _work_menu != null:
		_default_worker_path = _work_menu.get("worker_path")
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
	if _work_menu == null or not is_instance_valid(_work_menu):
		return
	var worker := actor if _is_work_compatible(actor) else _get_default_worker()
	if _work_menu.has_method("set_worker_actor"):
		_work_menu.call("set_worker_actor", worker)
		return
	if worker != null:
		_work_menu.set("worker_path", _work_menu.get_path_to(worker))
	else:
		_work_menu.set("worker_path", _default_worker_path)


func _get_default_worker() -> Node:
	if _work_menu == null or _default_worker_path.is_empty():
		return null
	return _work_menu.get_node_or_null(_default_worker_path)


func _is_work_compatible(actor: Node) -> bool:
	return actor != null and is_instance_valid(actor) and actor.has_method("request_work_at_entrance")
