extends Control
class_name SimpleProfilerHud

@export var show_only_in_debug_build: bool = true
@export var start_visible_in_debug_build: bool = true
@export var update_interval_seconds: float = 0.5
@export var panel_size: Vector2 = Vector2(560.0, 520.0)
@export var panel_offset: Vector2 = Vector2(16.0, 16.0)
@export var toggle_key: Key = KEY_F3
@export var toggle_ui_key: Key = KEY_F4
@export var toggle_map_key: Key = KEY_F5
@export var toggle_background_key: Key = KEY_F6
@export var toggle_actor_key: Key = KEY_F7
@export var listed_process_node_limit: int = 14

var _label: Label
var _timer := 0.0
var _frame_delta_accumulator := 0.0
var _frame_count := 0
var _last_average_frame_ms := 0.0
var _total_node_count := 0
var _process_node_count := 0
var _physics_node_count := 0
var _canvas_item_count := 0
var _process_node_paths: PackedStringArray = []
var _ui_diagnostic_hidden := false
var _map_diagnostic_hidden := false
var _background_diagnostic_hidden := false
var _actor_diagnostic_hidden := false
var _ui_diagnostic_state: Dictionary = {}


func _ready() -> void:
	if show_only_in_debug_build and not OS.is_debug_build():
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return

	visible = start_visible_in_debug_build
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
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == toggle_ui_key:
		_toggle_ui_diagnostic()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == toggle_map_key:
		_toggle_main_child_visibility("RobinRoomMap", "_map_diagnostic_hidden")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == toggle_background_key:
		_toggle_main_child_visibility("LocationBackground", "_background_diagnostic_hidden")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == toggle_actor_key:
		_toggle_main_child_visibility("Robin", "_actor_diagnostic_hidden")
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
	var process_ms := _seconds_to_ms(float(Performance.get_monitor(Performance.TIME_PROCESS)))
	var physics_ms := _seconds_to_ms(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var render_objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var render_primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var video_mb := _bytes_to_mb(float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	var texture_mb := _bytes_to_mb(float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	var physics_objects := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	var collision_pairs := int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	return "PROFILER HUD  F3: 表示切替\nF4:UI=%s F5:MAP=%s F6:BG=%s F7:ROBIN=%s\nFPS: %d / %.1f ms  avg: %.1f ms\nEngine.max_fps: %d  low_processor: %s\nProcess ms: %.2f  Physics ms: %.2f\nNodes: %d  _process: %d  _physics: %d\nCanvasItems: %d\nDraw calls: %d  Render objects: %d\nPrimitives: %d\nVideo MB: %.1f  Texture MB: %.1f\n2D physics objects: %d  pairs: %d\n\n_process nodes:\n%s" % [
		_hidden_label(_ui_diagnostic_hidden),
		_hidden_label(_map_diagnostic_hidden),
		_hidden_label(_background_diagnostic_hidden),
		_hidden_label(_actor_diagnostic_hidden),
		fps,
		fps_ms,
		_last_average_frame_ms,
		Engine.max_fps,
		str(OS.low_processor_usage_mode),
		process_ms,
		physics_ms,
		_total_node_count,
		_process_node_count,
		_physics_node_count,
		_canvas_item_count,
		draw_calls,
		render_objects,
		render_primitives,
		video_mb,
		texture_mb,
		physics_objects,
		collision_pairs,
		_get_process_node_text(),
	]


func _toggle_ui_diagnostic() -> void:
	_ui_diagnostic_hidden = not _ui_diagnostic_hidden
	var parent_node := get_parent()
	if parent_node == null:
		return
	if _ui_diagnostic_hidden:
		_ui_diagnostic_state.clear()
		for child in parent_node.get_children():
			if child == self:
				continue
			_capture_and_disable_ui_node(child)
	else:
		_restore_ui_diagnostic_state()
	_refresh()


func _capture_and_disable_ui_node(node: Node) -> void:
	if node == null:
		return
	var canvas_item := node as CanvasItem
	_ui_diagnostic_state[node.get_instance_id()] = {
		"node": node,
		"visible": canvas_item.visible if canvas_item != null else true,
		"process": node.is_processing(),
		"physics": node.is_physics_processing(),
	}
	if canvas_item != null:
		canvas_item.visible = false
	if node.is_processing():
		node.set_process(false)
	if node.is_physics_processing():
		node.set_physics_process(false)
	for child in node.get_children():
		_capture_and_disable_ui_node(child)


func _restore_ui_diagnostic_state() -> void:
	for state in _ui_diagnostic_state.values():
		if not state.has("node"):
			continue
		var node := state["node"] as Node
		if node == null or not is_instance_valid(node):
			continue
		var canvas_item := node as CanvasItem
		if canvas_item != null and state.has("visible"):
			canvas_item.visible = bool(state["visible"])
		if state.has("process"):
			node.set_process(bool(state["process"]))
		if state.has("physics"):
			node.set_physics_process(bool(state["physics"]))
	_ui_diagnostic_state.clear()


func _toggle_main_child_visibility(node_name: String, flag_property: StringName) -> void:
	var main_scene := _get_main_scene()
	if main_scene == null:
		return
	var target := main_scene.get_node_or_null(NodePath(node_name)) as CanvasItem
	if target == null:
		return
	var hidden := not bool(get(flag_property))
	set(flag_property, hidden)
	target.visible = not hidden
	_refresh()


func _get_main_scene() -> Node:
	var current := self as Node
	while current != null:
		if current.name == "MainScene":
			return current
		current = current.get_parent()
	return null


func _hidden_label(is_hidden: bool) -> String:
	return "OFF" if is_hidden else "ON"


func _scan_tree_counts() -> void:
	_total_node_count = 0
	_process_node_count = 0
	_physics_node_count = 0
	_canvas_item_count = 0
	_process_node_paths.clear()
	_count_node_recursive(get_tree().root)


func _count_node_recursive(node: Node) -> void:
	if node == null:
		return
	_total_node_count += 1
	if node.is_processing():
		_process_node_count += 1
		if _process_node_paths.size() < listed_process_node_limit:
			_process_node_paths.append(str(node.get_path()))
	if node.is_physics_processing():
		_physics_node_count += 1
	if node is CanvasItem:
		_canvas_item_count += 1
	for child in node.get_children():
		_count_node_recursive(child)


func _get_process_node_text() -> String:
	if _process_node_paths.is_empty():
		return "none"
	return "\n".join(_process_node_paths)


func _seconds_to_ms(seconds: float) -> float:
	return seconds * 1000.0


func _bytes_to_mb(bytes_value: float) -> float:
	return bytes_value / 1048576.0
