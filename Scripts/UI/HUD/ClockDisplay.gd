extends Control

@export var clock_path: NodePath
@export var panel_bg_color: Color = Color(0.01, 0.025, 0.04, 0.88)
@export var panel_border_color: Color = Color(0.33, 0.85, 1.0, 0.95)
@export var panel_glow_color: Color = Color(0.12, 0.65, 1.0, 0.38)
@export var time_text_color: Color = Color(0.86, 0.97, 1.0, 1.0)
@export var phase_text_color: Color = Color(0.33, 0.85, 1.0, 1.0)
@export_range(0, 32, 1) var panel_corner_radius: int = 16
@export_range(0, 32, 1) var panel_glow_size: int = 14

@onready var panel_container: PanelContainer = %PanelContainer
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel

var _clock: GameClockSystem


func _ready() -> void:
	_apply_neon_style()
	_clock = _find_clock()

	if _clock == null:
		time_label.text = "--:--"
		phase_label.text = "時刻なし"
		push_warning("ClockDisplay: GameClockSystem が見つかりません。")
		return

	_clock.time_changed.connect(_on_time_changed)
	_clock.phase_changed.connect(_on_phase_changed)
	_clock.season_changed.connect(_on_season_changed)

	_refresh()


func _apply_neon_style() -> void:
	if panel_container != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = panel_bg_color
		panel_style.border_color = panel_border_color
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(panel_corner_radius)
		panel_style.shadow_color = panel_glow_color
		panel_style.shadow_size = panel_glow_size
		panel_style.shadow_offset = Vector2.ZERO
		panel_style.set_content_margin_all(0.0)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	_apply_label_neon_style(time_label, time_text_color, 16, 1)
	_apply_label_neon_style(phase_label, phase_text_color, 13, 1)


func _apply_label_neon_style(label: Label, font_color: Color, font_size: int, shadow_outline_size: int) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(panel_border_color.r, panel_border_color.g, panel_border_color.b, 0.55))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", shadow_outline_size)


func _find_clock() -> GameClockSystem:
	if clock_path != NodePath():
		var node := get_node_or_null(clock_path)
		if node is GameClockSystem:
			return node

	var autoload_clock := get_node_or_null("/root/GameClock")
	if autoload_clock is GameClockSystem:
		return autoload_clock

	var group_nodes := get_tree().get_nodes_in_group("game_clock")
	if group_nodes.size() > 0 and group_nodes[0] is GameClockSystem:
		return group_nodes[0]

	return null


func _refresh() -> void:
	if _clock == null:
		return

	time_label.text = "%s  %s" % [
		_clock.get_day_text(),
		_clock.get_time_text(),
	]

	phase_label.text = _clock.get_phase_display_name()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_refresh()


func _on_phase_changed(_phase_id: String) -> void:
	_refresh()


func _on_season_changed(_season_id: String, _season_day: int, _season_year: int) -> void:
	_refresh()
