extends Node
class_name AICharacterBookReaderSelectionModule

@export var ai_actor_group_name: StringName = &"ai_character_actor"
@export var read_behavior_node_name: StringName = &"AICharacterReadBookBehaviorModule"

var _book_library_ui: Node
var _connected_actors: Array[WeakRef] = []


func _ready() -> void:
	_book_library_ui = get_parent()
	call_deferred("_connect_existing_actors")


func _exit_tree() -> void:
	_disconnect_actor_signals()


func _connect_existing_actors() -> void:
	_disconnect_actor_signals()
	if get_tree() == null:
		return
	for candidate in get_tree().get_nodes_in_group(ai_actor_group_name):
		var actor := candidate as Node
		if actor == null or not actor.has_signal("selected"):
			continue
		var callable := Callable(self, "_on_actor_selected")
		if not actor.is_connected("selected", callable):
			actor.connect("selected", callable)
		_connected_actors.append(weakref(actor))


func _disconnect_actor_signals() -> void:
	var callable := Callable(self, "_on_actor_selected")
	for actor_ref in _connected_actors:
		if actor_ref == null:
			continue
		var actor := actor_ref.get_ref() as Node
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.has_signal("selected") and actor.is_connected("selected", callable):
			actor.disconnect("selected", callable)
	_connected_actors.clear()


func _on_actor_selected(actor: Node) -> void:
	if _book_library_ui == null or not is_instance_valid(_book_library_ui):
		return
	var reader := _resolve_reader_node(actor)
	if reader == null:
		return
	var reader_path := _book_library_ui.get_path_to(reader)
	_book_library_ui.set("reader_actor_path", reader_path)


func _resolve_reader_node(actor: Node) -> Node:
	if actor == null or not is_instance_valid(actor):
		return null
	if actor.has_method("request_read_skill_book"):
		return actor
	var read_behavior := actor.get_node_or_null(NodePath(String(read_behavior_node_name)))
	if read_behavior != null and read_behavior.has_method("request_read_skill_book"):
		return read_behavior
	return null
