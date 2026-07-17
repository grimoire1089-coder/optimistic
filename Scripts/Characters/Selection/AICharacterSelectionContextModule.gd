extends Node
class_name AICharacterSelectionContextModule

signal selection_requested(actor: Node)
signal selected_actor_changed(actor: Node)

const CONTEXT_GROUP_NAME: StringName = &"ai_character_selection_context"

@export var actor_group_name: StringName = &"ai_character_actor"

var _selected_actor_ref: WeakRef
var _connected_actor_refs: Dictionary = {}
var _actor_exit_callables: Dictionary = {}


func _enter_tree() -> void:
	if not is_in_group(CONTEXT_GROUP_NAME):
		add_to_group(CONTEXT_GROUP_NAME)


func _ready() -> void:
	_connect_tree_node_added_signal()
	_connect_existing_actors()
	call_deferred("_connect_existing_actors")


func _exit_tree() -> void:
	_disconnect_tree_node_added_signal()
	_disconnect_actor_signals()
	_selected_actor_ref = null


func request_selection(actor: Node) -> bool:
	if not _is_selectable_actor(actor):
		return false
	_connect_actor(actor)
	var previous_actor := get_selected_actor()
	if previous_actor != actor:
		_selected_actor_ref = weakref(actor)
		selected_actor_changed.emit(actor)
	selection_requested.emit(actor)
	return true


func clear_selection(expected_actor: Node = null) -> bool:
	var current_actor := get_selected_actor()
	if current_actor == null:
		_selected_actor_ref = null
		return false
	if expected_actor != null and current_actor != expected_actor:
		return false
	_selected_actor_ref = null
	selected_actor_changed.emit(null)
	return true


func get_selected_actor() -> Node:
	if _selected_actor_ref == null:
		return null
	var actor := _selected_actor_ref.get_ref() as Node
	if actor == null or not is_instance_valid(actor):
		return null
	return actor


func is_actor_selected(actor: Node) -> bool:
	return actor != null and get_selected_actor() == actor


func get_debug_summary() -> String:
	var actor := get_selected_actor()
	return "selection actor=%s connected=%d" % [
		actor.name if actor != null else "none",
		_connected_actor_refs.size(),
	]


func _connect_tree_node_added_signal() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var callable := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callable):
		tree.node_added.connect(callable)


func _disconnect_tree_node_added_signal() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var callable := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callable):
		tree.node_added.disconnect(callable)


func _connect_existing_actors() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if actor_group_name != &"":
		for candidate in tree.get_nodes_in_group(actor_group_name):
			_connect_actor(candidate as Node)
	var parent_node := get_parent()
	if parent_node == null:
		return
	for child in parent_node.get_children():
		_connect_actor(child as Node)


func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	call_deferred("_connect_actor_from_weak_ref", weakref(node))


func _connect_actor_from_weak_ref(actor_ref: WeakRef) -> void:
	if actor_ref == null:
		return
	_connect_actor(actor_ref.get_ref() as Node)


func _connect_actor(actor: Node) -> void:
	if not _is_selectable_actor(actor):
		return
	var actor_id := actor.get_instance_id()
	if _connected_actor_refs.has(actor_id):
		return
	var selected_callable := Callable(self, "_on_actor_selected")
	if not actor.is_connected(&"selected", selected_callable):
		actor.connect(&"selected", selected_callable)
	var exit_callable := Callable(self, "_on_actor_tree_exiting").bind(actor_id)
	if not actor.tree_exiting.is_connected(exit_callable):
		actor.tree_exiting.connect(exit_callable)
	_connected_actor_refs[actor_id] = weakref(actor)
	_actor_exit_callables[actor_id] = exit_callable


func _disconnect_actor_signals() -> void:
	var selected_callable := Callable(self, "_on_actor_selected")
	for actor_id_value in _connected_actor_refs.keys():
		var actor_id := int(actor_id_value)
		var actor_ref := _connected_actor_refs.get(actor_id) as WeakRef
		if actor_ref == null:
			continue
		var actor := actor_ref.get_ref() as Node
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.has_signal(&"selected") and actor.is_connected(&"selected", selected_callable):
			actor.disconnect(&"selected", selected_callable)
		var exit_callable: Callable = _actor_exit_callables.get(actor_id, Callable())
		if exit_callable.is_valid() and actor.tree_exiting.is_connected(exit_callable):
			actor.tree_exiting.disconnect(exit_callable)
	_connected_actor_refs.clear()
	_actor_exit_callables.clear()


func _on_actor_selected(actor: Node) -> void:
	request_selection(actor)


func _on_actor_tree_exiting(actor_id: int) -> void:
	var selected_actor := get_selected_actor()
	if selected_actor != null and selected_actor.get_instance_id() == actor_id:
		_selected_actor_ref = null
		selected_actor_changed.emit(null)
	_connected_actor_refs.erase(actor_id)
	_actor_exit_callables.erase(actor_id)


func _is_selectable_actor(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if not actor.has_signal(&"selected"):
		return false
	if actor_group_name != &"" and actor.is_in_group(actor_group_name):
		return true
	return actor.has_method("get_needs_module")
