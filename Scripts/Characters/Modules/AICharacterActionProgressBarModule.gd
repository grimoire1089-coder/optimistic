extends Node
class_name AICharacterActionProgressBarModule

@export var hydrate_behavior_path: NodePath = NodePath("../AICharacterHydrateBehaviorModule")
@export var sleep_behavior_path: NodePath = NodePath("../AICharacterSleepBehaviorModule")
@export var bar_offset: Vector2 = Vector2(-42.0, -88.0)
@export var bar_size: Vector2 = Vector2(84.0, 10.0)
@export var background_color: Color = Color(0.02, 0.025, 0.035, 0.82)
@export var fill_color: Color = Color(0.1, 0.85, 1.0, 0.96)
@export var border_color: Color = Color(0.0, 0.95, 1.0, 0.72)
@export var corner_radius: int = 4

var _body: Node2D
var _hydrate_behavior: Node
var _sleep_behavior: Node
var _bar: ProgressBar


func _ready() -> void:
	_body = get_parent() as Node2D
	_resolve_refs()
	_ensure_bar()
	set_process(true)


func setup(body: Node2D) -> void:
	_body = body
	_resolve_refs()
	_ensure_bar()


func _process(_delta: float) -> void:
	_resolve_refs()
	_ensure_bar()
	_update_bar()


func _update_bar() -> void:
	if _bar == null:
		return
	var source := _get_active_progress_source()
	if source == null:
		_bar.visible = false
		return

	var progress := 0.0
	if source.has_method("get_action_progress_ratio"):
		progress = float(source.call("get_action_progress_ratio"))
	_bar.visible = true
	_bar.value = clampf(progress, 0.0, 1.0)


func _get_active_progress_source() -> Node:
	if _hydrate_behavior != null and _should_show_source(_hydrate_behavior):
		return _hydrate_behavior
	if _sleep_behavior != null and _should_show_source(_sleep_behavior):
		return _sleep_behavior
	return null


func _should_show_source(source: Node) -> bool:
	if source == null:
		return false
	if not source.has_method("is_action_progress_visible"):
		return false
	return source.call("is_action_progress_visible") == true


func _ensure_bar() -> void:
	if _bar != null and is_instance_valid(_bar):
		return
	if _body == null:
		return

	_bar = ProgressBar.new()
	_bar.name = "AIActionProgressBar"
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = bar_size
	_bar.size = bar_size
	_bar.position = bar_offset
	_bar.visible = false
	_bar.z_index = 200
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bar_style()
	_body.add_child(_bar)


func _apply_bar_style() -> void:
	if _bar == null:
		return
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = background_color
	background_style.border_color = border_color
	background_style.border_width_left = 1
	background_style.border_width_top = 1
	background_style.border_width_right = 1
	background_style.border_width_bottom = 1
	background_style.corner_radius_top_left = corner_radius
	background_style.corner_radius_top_right = corner_radius
	background_style.corner_radius_bottom_left = corner_radius
	background_style.corner_radius_bottom_right = corner_radius

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = corner_radius
	fill_style.corner_radius_top_right = corner_radius
	fill_style.corner_radius_bottom_left = corner_radius
	fill_style.corner_radius_bottom_right = corner_radius

	_bar.add_theme_stylebox_override("background", background_style)
	_bar.add_theme_stylebox_override("fill", fill_style)


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as Node2D
	if _hydrate_behavior == null and not hydrate_behavior_path.is_empty():
		_hydrate_behavior = get_node_or_null(hydrate_behavior_path)
	if _sleep_behavior == null and not sleep_behavior_path.is_empty():
		_sleep_behavior = get_node_or_null(sleep_behavior_path)
