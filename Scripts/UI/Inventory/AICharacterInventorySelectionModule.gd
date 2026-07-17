extends Node
class_name AICharacterInventorySelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"
const InventoryLookup := preload("res://Scripts/Characters/Modules/AICharacterInventoryLookup.gd")

var _inventory_ui: Node
var _selection_context: Node
var _default_actor_path: NodePath


func _ready() -> void:
	_inventory_ui = get_parent()
	if _inventory_ui != null:
		_default_actor_path = _inventory_ui.get("actor_path")
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
		_apply_actor(_get_default_actor())
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
		_apply_actor(_get_default_actor())
		return
	_on_selected_actor_changed(_selection_context.call("get_selected_actor") as Node)


func _on_selected_actor_changed(actor: Node) -> void:
	var target_actor := actor if _has_inventory(actor) else _get_default_actor()
	_apply_actor(target_actor)


func _apply_actor(actor: Node) -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	if actor == null or not is_instance_valid(actor):
		return
	if not _inventory_ui.has_method("set_actor"):
		return
	_inventory_ui.call("set_actor", actor)


func _get_default_actor() -> Node:
	if _inventory_ui == null or _default_actor_path.is_empty():
		return null
	return _inventory_ui.get_node_or_null(_default_actor_path)


func _has_inventory(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	return InventoryLookup.get_inventory_module(actor) != null
