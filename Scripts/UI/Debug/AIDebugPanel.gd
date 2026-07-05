extends Control
class_name AIDebugPanel

const PANEL_SIZE := Vector2(356.0, 336.0)
const PANEL_MARGIN := Vector2(24.0, 92.0)
const TOGGLE_SIZE := Vector2(64.0, 44.0)
const TOGGLE_MARGIN := Vector2(24.0, 24.0)
const FPS_LABEL_SIZE := Vector2(86.0, 32.0)
const FPS_LABEL_MARGIN := Vector2(96.0, 30.0)

@export var show_only_in_debug_build: bool = true
@export var actor_path: NodePath = NodePath("../../Robin")
@export var needs_module_path: NodePath = NodePath("../../Robin/AICharacterNeedsBundle/CharacterNeedsModule")
@export var weather_system_path: NodePath = NodePath("/root/WeatherSystem")
@export var refresh_interval_seconds: float = 0.2
@export var closed_refresh_interval_seconds: float = 1.0

var _actor: RobinWanderActor
var _needs_module: CharacterNeedsModule
var _weather_system: Node
var _modal_guard: Control
var _toggle_button: Button
var _fps_panel: PanelContainer
var _fps_label: Label
var _panel: PanelContainer
var _status_label: Label
var _weather_label: Label
var _needs_rows: Dictionary = {}
var _refresh_timer := 0.0


func _ready() -> void:
	if show_only_in_debug_build and not OS.is_debug_build():
		visible = false
		set_process(false)
		return

	z_index = 900
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_resolve_refs()
	_build_modal_guard()
	_build_toggle_button()
	_build_fps_display()
	_build_panel()
	call_deferred("_bring_debug_ui_to_front")
	_refresh_fps_label()
	set_process(true)


func _process(delta: float) -> void:
	var interval := closed_refresh_interval_seconds
	if _is_panel_open():
		interval = refresh_interval_seconds
	_refresh_timer -= maxf(delta, 0.0)
	if _refresh_timer > 0.0:
		return
	_refresh_timer = maxf(interval, 0.05)
	if _is_panel_open():
		_resolve_refs()
		_refresh_panel()
	else:
		_refresh_fps_label()


func _build_modal_guard() -> void:
	_modal_guard = Control.new()
	_modal_guard.name = "AIDebugModalGuard"
	_modal_guard.z_index = 1
	_modal_guard.visible = false
	_modal_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_guard.focus_mode = Control.FOCUS_NONE
	_modal_guard.anchor_left = 0.0
	_modal_guard.anchor_top = 0.0
	_modal_guard.anchor_right = 1.0
	_modal_guard.anchor_bottom = 1.0
	_modal_guard.offset_left = 0.0
	_modal_guard.offset_top = 0.0
	_modal_guard.offset_right = 0.0
	_modal_guard.offset_bottom = 0.0
	add_child(_modal_guard)


func _build_toggle_button() -> void:
	_toggle_button = Button.new()
	_toggle_button.name = "AIDebugToggleButton"
	_toggle_button.z_index = 3
	_toggle_button.custom_minimum_size = TOGGLE_SIZE
	_toggle_button.size = TOGGLE_SIZE
	_toggle_button.toggle_mode = true
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle_button.text = "DBG"
	_toggle_button.tooltip_text = "AIデバッグパネルを開閉"
	_place_bottom_right_control(_toggle_button, TOGGLE_MARGIN, TOGGLE_SIZE)
	_apply_button_style(_toggle_button, Color(0.02, 0.025, 0.035, 0.94), Color(0.95, 0.55, 1.0, 0.95), Color(1.0, 0.78, 1.0, 1.0))
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)


func _build_fps_display() -> void:
	_fps_panel = PanelContainer.new()
	_fps_panel.name = "GameFpsDisplay"
	_fps_panel.z_index = 3
	_fps_panel.custom_minimum_size = FPS_LABEL_SIZE
	_fps_panel.size = FPS_LABEL_SIZE
	_fps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_bottom_right_control(_fps_panel, FPS_LABEL_MARGIN, FPS_LABEL_SIZE)
	_apply_fps_panel_style(_fps_panel)
	add_child(_fps_panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	_fps_panel.add_child(margin)

	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.text = "FPS --"
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.add_theme_color_override("font_color", Color(0.76, 1.0, 0.78, 1.0))
	_fps_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_fps_label)
	_refresh_fps_label()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AIDebugPanelBody"
	_panel.z_index = 2
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_place_bottom_right_control(_panel, PANEL_MARGIN, PANEL_SIZE)
	_apply_panel_style(_panel)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.horizontal_scroll_mode = 0
	scroll.vertical_scroll_mode = 1
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)

	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 8)
	rows.add_child(title_row)

	var title := Label.new()
	title.text = "AI DEBUG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 17)
	title_row.add_child(title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(52.0, 28.0)
	close_button.text = "閉じる"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_on_close_pressed)
	_apply_button_style(close_button, Color(0.055, 0.025, 0.045, 0.96), Color(1.0, 0.32, 0.72, 0.95), Color(1.0, 0.82, 0.92, 1.0))
	title_row.add_child(close_button)

	_status_label = Label.new()
	_status_label.text = "対象: 未接続"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.98, 1.0, 1.0))
	_status_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(_status_label)

	_build_weather_controls(rows)

	var separator := HSeparator.new()
	rows.add_child(separator)

	var needs_title := Label.new()
	needs_title.text = "欲求数値操作"
	needs_title.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0, 1.0))
	needs_title.add_theme_font_size_override("font_size", 13)
	rows.add_child(needs_title)

	var needs_container := VBoxContainer.new()
	needs_container.name = "NeedsRows"
	needs_container.add_theme_constant_override("separation", 4)
	rows.add_child(needs_container)
	_rebuild_need_rows(needs_container)

	var action_separator := HSeparator.new()
	rows.add_child(action_separator)

	var rescue_button := Button.new()
	rescue_button.name = "ResetAndWarpButton"
	rescue_button.custom_minimum_size = Vector2(320.0, 42.0)
	rescue_button.text = "行動リセット + 最寄りグリッドへ救出"
	rescue_button.tooltip_text = "スタック時用。現在行動を止め、2x4足跡で置ける最寄りセルへ移動します。"
	rescue_button.pressed.connect(_on_reset_and_warp_pressed)
	_apply_button_style(rescue_button, Color(0.055, 0.035, 0.06, 0.96), Color(1.0, 0.55, 0.15, 0.95), Color(1.0, 0.86, 0.62, 1.0))
	rows.add_child(rescue_button)

	var snap_button := Button.new()
	snap_button.name = "SnapGridButton"
	snap_button.custom_minimum_size = Vector2(320.0, 34.0)
	snap_button.text = "現在位置をグリッドへ整列"
	snap_button.tooltip_text = "行動はなるべく維持したまま、移動可能な最寄りグリッドへ寄せます。"
	snap_button.pressed.connect(_on_snap_grid_pressed)
	_apply_button_style(snap_button, Color(0.02, 0.045, 0.055, 0.96), Color(0.2, 0.95, 1.0, 0.92), Color(0.78, 0.98, 1.0, 1.0))
	rows.add_child(snap_button)


func _build_weather_controls(parent: VBoxContainer) -> void:
	var weather_separator := HSeparator.new()
	parent.add_child(weather_separator)

	_weather_label = Label.new()
	_weather_label.name = "WeatherLabel"
	_weather_label.text = _make_weather_text()
	_weather_label.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0, 1.0))
	_weather_label.add_theme_font_size_override("font_size", 12)
	parent.add_child(_weather_label)

	var weather_buttons := HBoxContainer.new()
	weather_buttons.name = "WeatherButtons"
	weather_buttons.add_theme_constant_override("separation", 4)
	parent.add_child(weather_buttons)

	var sunny_button := _make_weather_button("晴れ", "天候を晴れにします")
	sunny_button.pressed.connect(Callable(self, "_on_set_weather_pressed").bind(&"sunny"))
	weather_buttons.add_child(sunny_button)

	var rain_button := _make_weather_button("雨", "天候を雨にします。雨の環境音確認用。")
	rain_button.pressed.connect(Callable(self, "_on_set_weather_pressed").bind(&"rain"))
	weather_buttons.add_child(rain_button)

	var roll_button := _make_weather_button("抽選", "今日の天候を抽選し直します")
	roll_button.pressed.connect(_on_roll_weather_pressed)
	weather_buttons.add_child(roll_button)


func _make_weather_button(label_text: String, tooltip_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(74.0, 28.0)
	button.text = label_text
	button.tooltip_text = tooltip_text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(button, Color(0.02, 0.035, 0.055, 0.96), Color(0.34, 0.78, 1.0, 0.88), Color(0.82, 0.95, 1.0, 1.0))
	return button


func _rebuild_need_rows(parent: VBoxContainer) -> void:
	_needs_rows.clear()
	var needs := _get_need_instances()
	if needs.is_empty():
		var empty_label := Label.new()
		empty_label.text = "欲求モジュールが見つかりません"
		empty_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.72, 1.0))
		parent.add_child(empty_label)
		return

	for need in needs:
		if need == null or need.definition == null:
			continue
		var need_id := need.definition.need_id
		var row := HBoxContainer.new()
		row.name = "%sRow" % String(need_id)
		row.add_theme_constant_override("separation", 4)
		parent.add_child(row)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(70.0, 26.0)
		name_label.text = need.definition.display_name
		name_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
		row.add_child(name_label)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(76.0, 26.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.78, 1.0))
		row.add_child(value_label)

		_add_need_button(row, "-10", need_id, -10.0)
		_add_need_button(row, "+10", need_id, 10.0)
		_add_need_set_button(row, "0", need_id, 0.0)
		_add_need_set_button(row, "MAX", need_id, need.definition.max_value)

		_needs_rows[need_id] = value_label


func _add_need_button(row: HBoxContainer, label_text: String, need_id: StringName, delta: float) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(38.0, 26.0)
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(Callable(self, "_on_need_delta_pressed").bind(need_id, delta))
	row.add_child(button)


func _add_need_set_button(row: HBoxContainer, label_text: String, need_id: StringName, value: float) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44.0, 26.0)
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(Callable(self, "_on_need_set_pressed").bind(need_id, value))
	row.add_child(button)


func _on_toggle_pressed() -> void:
	if _toggle_button == null:
		return
	_set_panel_open(_toggle_button.button_pressed)


func _on_close_pressed() -> void:
	_set_panel_open(false)


func _set_panel_open(is_open: bool) -> void:
	if _modal_guard != null:
		_modal_guard.visible = is_open
	if _panel != null:
		_panel.visible = is_open
	if _toggle_button != null:
		_toggle_button.set_pressed_no_signal(is_open)
		_toggle_button.text = "DBG-" if is_open else "DBG"
	_bring_debug_ui_to_front()
	if is_open:
		_resolve_refs()
		_refresh_panel()
	else:
		_refresh_fps_label()


func _is_panel_open() -> bool:
	return _panel != null and _panel.visible


func _bring_debug_ui_to_front() -> void:
	move_to_front()
	if _modal_guard != null:
		_modal_guard.move_to_front()
	if _panel != null:
		_panel.move_to_front()
	if _fps_panel != null:
		_fps_panel.move_to_front()
	if _toggle_button != null:
		_toggle_button.move_to_front()


func _on_need_delta_pressed(need_id: StringName, delta: float) -> void:
	if _needs_module == null:
		return
	var current_value := _needs_module.get_need_value(need_id, 0.0)
	_needs_module.set_need_value(need_id, current_value + delta)
	_refresh_panel()


func _on_need_set_pressed(need_id: StringName, value: float) -> void:
	if _needs_module == null:
		return
	_needs_module.set_need_value(need_id, value)
	_refresh_panel()


func _on_set_weather_pressed(weather_id: StringName) -> void:
	_resolve_refs()
	if _weather_system == null or not _weather_system.has_method("set_weather"):
		_push_debug("[AI Debug] WeatherSystem が見つかりません")
		return
	_weather_system.call("set_weather", weather_id)
	_push_debug("[AI Debug] 天候を %s に変更" % _get_weather_display_name(weather_id))
	_refresh_panel()


func _on_roll_weather_pressed() -> void:
	_resolve_refs()
	if _weather_system == null or not _weather_system.has_method("update_daily_weather"):
		_push_debug("[AI Debug] WeatherSystem が見つかりません")
		return
	var day: int = 1
	if GameClock != null:
		day = int(GameClock.day)
	_weather_system.call("update_daily_weather", day)
	_push_debug("[AI Debug] 天候を抽選更新")
	_refresh_panel()


func _on_reset_and_warp_pressed() -> void:
	if _actor == null:
		_push_debug("[AI Debug] 対象AIが見つかりません")
		return
	var success := false
	if _actor.has_method("debug_reset_actions_and_snap_to_grid"):
		success = bool(_actor.call("debug_reset_actions_and_snap_to_grid"))
	else:
		success = _actor.wander_module != null and _actor.wander_module.clamp_body_to_movement_area()
	_push_debug("[AI Debug] 行動リセット+救出 %s" % ("OK" if success else "変化なし"))
	_refresh_panel()


func _on_snap_grid_pressed() -> void:
	if _actor == null:
		_push_debug("[AI Debug] 対象AIが見つかりません")
		return
	var success := false
	if _actor.has_method("snap_to_nearest_walkable_grid"):
		success = bool(_actor.call("snap_to_nearest_walkable_grid"))
	else:
		success = _actor.wander_module != null and _actor.wander_module.clamp_body_to_movement_area()
	_push_debug("[AI Debug] グリッド整列 %s" % ("OK" if success else "変化なし"))
	_refresh_panel()


func _refresh_panel() -> void:
	_refresh_fps_label()
	if not _is_panel_open():
		return

	if _status_label != null:
		_status_label.text = _make_status_text()
	if _weather_label != null:
		_weather_label.text = _make_weather_text()

	if _needs_rows.is_empty():
		return
	for need in _get_need_instances():
		if need == null or need.definition == null:
			continue
		var need_id := need.definition.need_id
		if not _needs_rows.has(need_id):
			continue
		var label := _needs_rows[need_id] as Label
		if label == null:
			continue
		label.text = "%.1f / %.0f" % [need.value, need.definition.max_value]


func _refresh_fps_label() -> void:
	if _fps_label == null:
		return
	_fps_label.text = "FPS %d" % int(Engine.get_frames_per_second())


func _make_status_text() -> String:
	if _actor == null:
		return "対象: 未接続"
	var action_text := "?"
	if _actor.has_method("get_current_action_display_text"):
		action_text = str(_actor.call("get_current_action_display_text"))
	var grid_text := "?"
	if _actor.has_method("get_debug_actor_grid_summary"):
		grid_text = str(_actor.call("get_debug_actor_grid_summary"))
	return "対象: %s / 行動: %s\n%s" % [_actor.display_name, action_text, grid_text]


func _make_weather_text() -> String:
	_resolve_refs()
	if _weather_system == null:
		return "天候: WeatherSystem 未接続"
	var weather_id: StringName = &""
	if _weather_system.has_method("get_weather_id"):
		weather_id = StringName(String(_weather_system.call("get_weather_id")))
	return "天候: %s" % _get_weather_display_name(weather_id)


func _get_weather_display_name(weather_id: StringName) -> String:
	if _weather_system != null and _weather_system.has_method("get_weather_display_name"):
		return String(_weather_system.call("get_weather_display_name", weather_id))
	match weather_id:
		&"rain":
			return "雨"
		&"sunny":
			return "晴れ"
		_:
			return String(weather_id)


func _get_need_instances() -> Array[NeedInstance]:
	var result: Array[NeedInstance] = []
	if _needs_module == null:
		return result
	var character_needs := _needs_module.get_character_needs()
	if character_needs == null:
		return result
	for need in character_needs.needs:
		if need != null and need is NeedInstance:
			result.append(need)
	return result


func _place_bottom_right_control(control: Control, margin: Vector2, control_size: Vector2) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = -margin.x - control_size.x
	control.offset_top = -margin.y - control_size.y
	control.offset_right = -margin.x
	control.offset_bottom = -margin.y


func _apply_fps_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.02, 0.018, 0.88)
	style.border_color = Color(0.38, 1.0, 0.48, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.18, 1.0, 0.32, 0.2)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.018, 0.026, 0.96)
	style.border_color = Color(0.85, 0.28, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.65, 0.15, 1.0, 0.28)
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_style(button: Button, bg_color: Color, border_color: Color, font_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_font_size_override("font_size", 11)


func _push_debug(message: String) -> void:
	var log_node := get_tree().get_first_node_in_group(&"message_log")
	if log_node != null and log_node.has_method("add_debug_message"):
		log_node.call("add_debug_message", message)
	else:
		print(message)


func _resolve_refs() -> void:
	if (_actor == null or not is_instance_valid(_actor)) and not actor_path.is_empty():
		_actor = get_node_or_null(actor_path) as RobinWanderActor
	if (_needs_module == null or not is_instance_valid(_needs_module)) and not needs_module_path.is_empty():
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if (_weather_system == null or not is_instance_valid(_weather_system)) and not weather_system_path.is_empty():
		_weather_system = get_node_or_null(weather_system_path)
