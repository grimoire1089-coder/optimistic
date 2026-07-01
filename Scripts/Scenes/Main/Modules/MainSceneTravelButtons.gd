extends Control
class_name MainSceneTravelButtons

signal travel_to_infrastructure_requested
signal travel_to_robin_room_requested

@export var to_infrastructure_button_path: NodePath = NodePath("ToInfrastructureRoomButton")
@export var to_robin_room_button_path: NodePath = NodePath("ToRobinRoomButton")
@export var to_infrastructure_label_text: String = "インフラへ"
@export var to_robin_room_label_text: String = "部屋へ戻る"
@export var button_position: Vector2 = Vector2(52.0, 72.0)
@export var button_size: Vector2 = Vector2(180.0, 38.0)

var _to_infrastructure_button: Button
var _to_robin_room_button: Button


func _ready() -> void:
	_ensure_buttons()
	_resolve_buttons()
	_apply_button_layouts()
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


func _ensure_buttons() -> void:
	if get_node_or_null(to_infrastructure_button_path) == null:
		_create_button(String(to_infrastructure_button_path), to_infrastructure_label_text, true)
	if get_node_or_null(to_robin_room_button_path) == null:
		_create_button(String(to_robin_room_button_path), to_robin_room_label_text, false)


func _create_button(button_name: String, text_value: String, visible_on_start: bool) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text_value
	button.visible = visible_on_start
	add_child(button)
	_apply_button_layout(button)
	return button


func _apply_button_layouts() -> void:
	_apply_button_layout(_to_infrastructure_button)
	_apply_button_layout(_to_robin_room_button)


func _apply_button_layout(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = button_size
	button.offset_left = button_position.x
	button.offset_top = button_position.y
	button.offset_right = button_position.x + button_size.x
	button.offset_bottom = button_position.y + button_size.y
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.08, 0.10, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.14, 0.17, 0.98), Color(0.00, 1.65, 1.65, 0.95), 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.06, 0.06, 0.07, 0.65), Color(0.18, 0.18, 0.20, 0.8), 1))


func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4.0)
	return style


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
