extends Node
class_name AICharacterBookReaderSelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"

@export var read_behavior_node_name: StringName = &"AICharacterReadBookBehaviorModule"

var _book_library_ui: Node
var _selection_context: Node
var _default_reader_actor_path: NodePath


func _ready() -> void:
	_book_library_ui = get_parent()
	if _book_library_ui != null:
		_default_reader_actor_path = _book_library_ui.get("reader_actor_path")
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
	if _book_library_ui == null or not is_instance_valid(_book_library_ui):
		return
	var reader := _resolve_reader_node(actor)
	if reader == null:
		_book_library_ui.set("reader_actor_path", _default_reader_actor_path)
		return
	_book_library_ui.set("reader_actor_path", _book_library_ui.get_path_to(reader))


func _resolve_reader_node(actor: Node) -> Node:
	if actor == null or not is_instance_valid(actor):
		return null
	if actor.has_method("request_read_skill_book"):
		return actor
	var read_behavior := actor.get_node_or_null(NodePath(String(read_behavior_node_name)))
	if read_behavior != null and read_behavior.has_method("request_read_skill_book"):
		return read_behavior
	return null
