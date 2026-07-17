extends Node
class_name AICharacterCraftSelectionModule

@export var ai_actor_group_name: StringName = &"ai_character_actor"
@export var craft_behavior_node_name: StringName = &"AICharacterCraftBehaviorModule"

var _craft_menu: Node
var _connected_actors: Array[WeakRef] = []


func _ready() -> void:
	_craft_menu = get_parent()
	_connect_existing_actors()
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
	if _craft_menu == null or not is_instance_valid(_craft_menu):
		return
	if not _has_craft_request_target(actor):
		return
	_craft_menu.set("actor_path", _craft_menu.get_path_to(actor))


func _has_craft_request_target(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.has_method("request_craft"):
		return true
	var behavior := actor.get_node_or_null(NodePath(String(craft_behavior_node_name)))
	return behavior != null and behavior.has_method("request_craft")
