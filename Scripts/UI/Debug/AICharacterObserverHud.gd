extends Control
class_name AICharacterObserverHud

const PANEL_SIZE := Vector2(520.0, 520.0)
const PANEL_MARGIN := Vector2(24.0, 24.0)

@export var show_only_in_debug_build: bool = true
@export var actor_group_name: StringName = &"ai_character_actor"
@export var refresh_interval_seconds: float = 0.25
@export var max_need_rows_per_actor: int = 8

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _close_button: Button
var _refresh_timer: float = 0.0


func _ready() -> void:
	if show_only_in_debug_build and not OS.is_debug_build():
		visible = false
		set_process(false)
		return

	z_index = 920
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_build_ui()
	set_panel_open(false)
	set_process(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if show_only_in_debug_build and not OS.is_debug_build():
		return
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F2:
		return
	toggle_panel()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_panel_open():
		return
	_refresh_timer -= maxf(delta, 0.0)
	if _refresh_timer > 0.0:
		return
	_refresh_timer = maxf(refresh_interval_seconds, 0.05)
	_refresh()


func toggle_panel() -> void:
	set_panel_open(not is_panel_open())


func set_panel_open(is_open: bool) -> void:
	if _panel == null:
		return
	_panel.visible = is_open
	_refresh_timer = 0.0
	if is_open:
		_refresh()


func is_panel_open() -> bool:
	return _panel != null and _panel.visible


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AICharacterObserverPanel"
	_panel.z_index = 2
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_place_top_right_control(_panel, PANEL_MARGIN, PANEL_SIZE)
	_apply_panel_style(_panel)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "AI OBSERVER  F2"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color(0.82, 1.0, 1.0, 1.0))
	_title_label.add_theme_font_size_override("font_size", 17)
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.custom_minimum_size = Vector2(64.0, 30.0)
	_close_button.text = "閉じる"
	_close_button.tooltip_text = "F2でも閉じられます"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.pressed.connect(_on_close_pressed)
	_apply_button_style(_close_button)
	header.add_child(_close_button)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "F2: 開閉 / 1キャラ1ライン観測 / 表示中のみ更新"
	hint.add_theme_color_override("font_color", Color(0.58, 0.78, 0.86, 1.0))
	hint.add_theme_font_size_override("font_size", 12)
	root.add_child(hint)

	var separator := HSeparator.new()
	root.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0, 1.0))
	_body_label.add_theme_font_size_override("font_size", 12)
	scroll.add_child(_body_label)


func _refresh() -> void:
	var actors := _collect_ai_actors()
	if _title_label != null:
		_title_label.text = "AI OBSERVER  F2  /  %d actors" % actors.size()
	if _body_label == null:
		return
	if actors.is_empty():
		_body_label.text = "AIキャラクターが見つかりません。group=%s" % String(actor_group_name)
		return

	var lines: Array[String] = []
	for index in range(actors.size()):
		var actor := actors[index]
		_append_actor_lines(lines, actor, index)
	_body_label.text = _join_string_array(lines, "\n")


func _collect_ai_actors() -> Array[Node]:
	var result: Array[Node] = []
	if get_tree() == null:
		return result
	for value in get_tree().get_nodes_in_group(actor_group_name):
		var actor := value as Node
		if actor == null or not is_instance_valid(actor):
			continue
		result.append(actor)
	result.sort_custom(Callable(self, "_sort_actor_by_name"))
	return result


func _sort_actor_by_name(a: Node, b: Node) -> bool:
	return _get_actor_display_name(a) < _get_actor_display_name(b)


func _append_actor_lines(lines: Array[String], actor: Node, index: int) -> void:
	var title := "[%02d] %s  node=%s" % [index + 1, _get_actor_display_name(actor), actor.name]
	lines.append(title)
	lines.append("  action=%s / text=%s / moving=%s" % [
		String(_call_string_name(actor, "get_current_need_action_id", &"")),
		_call_string(actor, "get_current_action_display_text", ""),
		str(_call_bool(actor, "is_ai_character_moving", false)),
	])
	lines.append("  lowest_need=%s / pos=%s / vel=%s" % [
		String(_call_string_name(actor, "get_current_lowest_need_id", &"")),
		_format_actor_position(actor),
		_format_actor_velocity(actor),
	])

	if actor.has_method("get_ai_action_runner_debug_summary"):
		lines.append("  runner=%s" % _call_string(actor, "get_ai_action_runner_debug_summary", ""))
	elif actor.has_method("get_ai_action_runner_action_id"):
		lines.append("  runner_action=%s" % String(_call_string_name(actor, "get_ai_action_runner_action_id", &"")))
	else:
		lines.append("  runner=not connected")

	var needs_text := _make_needs_text(actor)
	if not needs_text.is_empty():
		lines.append("  needs: %s" % needs_text)
	lines.append("")


func _make_needs_text(actor: Node) -> String:
	var needs_module := _get_actor_needs_module(actor)
	if needs_module == null or not needs_module.has_method("get_character_needs"):
		return ""
	var character_needs := needs_module.call("get_character_needs") as CharacterNeeds
	if character_needs == null:
		return ""
	var parts: Array[String] = []
	var count := 0
	for need in character_needs.needs:
		if need == null or need.definition == null:
			continue
		parts.append("%s %.0f/%.0f %s" % [
			_get_need_display_name(need),
			need.value,
			need.definition.max_value,
			String(need.get_state()),
		])
		count += 1
		if count >= max_need_rows_per_actor:
			break
	return _join_string_array(parts, " | ")


func _get_actor_needs_module(actor: Node) -> Node:
	if actor == null or not actor.has_method("get_needs_module"):
		return null
	return actor.call("get_needs_module") as Node


func _get_need_display_name(need: NeedInstance) -> String:
	if need == null or need.definition == null:
		return "?"
	if not need.definition.display_name.is_empty():
		return need.definition.display_name
	return String(need.definition.need_id)


func _get_actor_display_name(actor: Node) -> String:
	if actor == null:
		return "AI"
	var value: Variant = actor.get("display_name")
	if value is String and not String(value).is_empty():
		return String(value)
	return actor.name


func _format_actor_position(actor: Node) -> String:
	var node_2d := actor as Node2D
	if node_2d == null:
		return "-"
	return "(%.1f, %.1f)" % [node_2d.global_position.x, node_2d.global_position.y]


func _format_actor_velocity(actor: Node) -> String:
	var body := actor as CharacterBody2D
	if body == null:
		return "-"
	return "(%.1f, %.1f)" % [body.velocity.x, body.velocity.y]


func _call_string(actor: Node, method_name: StringName, fallback: String) -> String:
	if actor == null or not actor.has_method(method_name):
		return fallback
	return String(actor.call(method_name))


func _call_string_name(actor: Node, method_name: StringName, fallback: StringName) -> StringName:
	if actor == null or not actor.has_method(method_name):
		return fallback
	var value: Variant = actor.call(method_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return fallback


func _call_bool(actor: Node, method_name: StringName, fallback: bool) -> bool:
	if actor == null or not actor.has_method(method_name):
		return fallback
	return bool(actor.call(method_name))


func _join_string_array(parts: Array[String], separator: String) -> String:
	if parts.is_empty():
		return ""
	var text := parts[0]
	for index in range(1, parts.size()):
		text += separator + parts[index]
	return text


func _on_close_pressed() -> void:
	set_panel_open(false)


func _place_top_right_control(control: Control, top_right_margin: Vector2, control_size: Vector2) -> void:
	if control == null:
		return
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = -top_right_margin.x - control_size.x
	control.offset_top = top_right_margin.y
	control.offset_right = -top_right_margin.x
	control.offset_bottom = top_right_margin.y + control_size.y


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.018, 0.030, 1.0)
	style.border_color = Color(0.30, 0.88, 1.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.70)
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.040, 0.060, 1.0)
	style.border_color = Color(0.35, 0.90, 1.0, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 12)
