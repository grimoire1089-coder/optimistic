extends Control
class_name SimpleProfilerHud

@export var update_interval_seconds: float = 0.5
@export var panel_size: Vector2 = Vector2(340.0, 180.0)
@export var panel_offset: Vector2 = Vector2(16.0, 16.0)
@export var toggle_key: Key = KEY_F3

var _label: Label
var _timer := 0.0
var _frame_delta_accumulator := 0.0
var _frame_count := 0
var _last_average_frame_ms := 0.0
var _total_node_count := 0
var _process_node_count := 0
var _physics_node_count := 0
var _canvas_item_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	set_process(true)
	set_process_unhandled_input(true)
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	_frame_delta_accumulator += maxf(delta, 0.0)
	_frame_count += 1
	_timer -= maxf(delta, 0.0)
	if _timer > 0.0:
		return
	_timer = maxf(update_interval_seconds, 0.1)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == toggle_key:
			visible = not visible
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	custom_minimum_size = panel_size
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = panel_offset.x
	offset_top = panel_offset.y
	offset_right = panel_offset.x + panel_size.x
	offset_bottom = panel_offset.y + panel_size.y

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.98, 1.0))
	margin.add_child(_label)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.018, 0.028, 0.82)
	style.border_color = Color(0.18, 0.92, 1.0, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.85, 1.0, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	return style


func _refresh() -> void:
	if _label == null:
		return
	if _frame_count > 0:
		_last_average_frame_ms = (_frame_delta_accumulator / float(_frame_count)) * 1000.0
		_frame_delta_accumulator = 0.0
		_frame_count = 0
	_scan_tree_counts()
	_label.text = _build_text()


func _build_text() -> String:
	var fps := Engine.get_frames_per_second()
	var fps_ms := 0.0
	if fps > 0:
		fps_ms = 1000.0 / float(fps)
	return "PROFILER HUD  F3: 表示切替\nFPS: %d / %.1f ms  avg: %.1f ms\nNodes: %d\n_process nodes: %d\n_physics nodes: %d\nCanvasItems: %d" % [
		fps,
		fps_ms,
		_last_average_frame_ms,
		_total_node_count,
		_process_node_count,
		_physics_node_count,
		_canvas_item_count,
	]


func _scan_tree_counts() -> void:
	_total_node_count = 0
	_process_node_count = 0
	_physics_node_count = 0
	_canvas_item_count = 0
	_count_node_recursive(get_tree().root)


func _count_node_recursive(node: Node) -> void:
	if node == null:
		return
	_total_node_count += 1
	if node.is_processing():
		_process_node_count += 1
	if node.is_physics_processing():
		_physics_node_count += 1
	if node is CanvasItem:
		_canvas_item_count += 1
	for child in node.get_children():
		_count_node_recursive(child)
