extends Control
class_name MainSceneTravelButtons

signal travel_to_infrastructure_requested
signal travel_to_robin_room_requested

@export var to_infrastructure_button_path: NodePath = NodePath("ToInfrastructureRoomButton")
@export var to_robin_room_button_path: NodePath = NodePath("ToRobinRoomButton")

var _to_infrastructure_button: Button
var _to_robin_room_button: Button


func _ready() -> void:
	_resolve_buttons()
	_connect_buttons()
	_apply_start_state()


func show_for_robin_room() -> void:
	_resolve_buttons()
	if _to_infrastructure_button != null:
		_to_infrastructure_button.visible = true
		_to_infrastructure_button.disabled = false
	if _to_robin_room_button != null:
		_to_robin_room_button.visible = false
		_to_robin_room_button.disabled = true


func show_for_infrastructure_room() -> void:
	_resolve_buttons()
	if _to_infrastructure_button != null:
		_to_infrastructure_button.visible = false
		_to_infrastructure_button.disabled = true
	if _to_robin_room_button != null:
		_to_robin_room_button.visible = true
		_to_robin_room_button.disabled = false


func get_to_infrastructure_button() -> Button:
	_resolve_buttons()
	return _to_infrastructure_button


func get_to_robin_room_button() -> Button:
	_resolve_buttons()
	return _to_robin_room_button


func _apply_start_state() -> void:
	show_for_robin_room()


func _connect_buttons() -> void:
	if _to_infrastructure_button != null:
		var to_infrastructure_callable := Callable(self, "_on_to_infrastructure_pressed")
		if not _to_infrastructure_button.pressed.is_connected(to_infrastructure_callable):
			_to_infrastructure_button.pressed.connect(to_infrastructure_callable)
	if _to_robin_room_button != null:
		var to_robin_room_callable := Callable(self, "_on_to_robin_room_pressed")
		if not _to_robin_room_button.pressed.is_connected(to_robin_room_callable):
			_to_robin_room_button.pressed.connect(to_robin_room_callable)


func _on_to_infrastructure_pressed() -> void:
	travel_to_infrastructure_requested.emit()


func _on_to_robin_room_pressed() -> void:
	travel_to_robin_room_requested.emit()


func _resolve_buttons() -> void:
	if _to_infrastructure_button == null and not to_infrastructure_button_path.is_empty():
		_to_infrastructure_button = get_node_or_null(to_infrastructure_button_path) as Button
	if _to_robin_room_button == null and not to_robin_room_button_path.is_empty():
		_to_robin_room_button = get_node_or_null(to_robin_room_button_path) as Button
