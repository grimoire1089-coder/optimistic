extends Control

@export var clock_path: NodePath
@export var weather_path: NodePath
@export var panel_bg_color: Color = Color(0.01, 0.025, 0.04, 0.88)
@export var panel_border_color: Color = Color(0.33, 0.85, 1.0, 0.95)
@export var panel_glow_color: Color = Color(0.12, 0.65, 1.0, 0.38)
@export var time_text_color: Color = Color(0.86, 0.97, 1.0, 1.0)
@export var phase_text_color: Color = Color(0.33, 0.85, 1.0, 1.0)
@export_range(0, 8, 1) var panel_border_width: int = 3
@export_range(0, 32, 1) var panel_corner_radius: int = 16
@export_range(0, 32, 1) var panel_glow_size: int = 0

@onready var bgm_mute_button: Button = %BGMMuteButton
@onready var panel_container: PanelContainer = %PanelContainer
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel

var _clock: GameClockSystem
var _weather: GameWeatherSystem


func _ready() -> void:
	_apply_neon_style()
	_setup_bgm_mute_button()
	_clock = _find_clock()
	_weather = _find_weather()

	if _weather != null:
		_connect_weather_signals()

	if _clock == null:
		time_label.text = "--:--"
		phase_label.text = "%s / 時刻なし" % _get_weather_display_text()
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
		panel_style.set_border_width_all(panel_border_width)
		panel_style.set_corner_radius_all(panel_corner_radius)
		panel_style.shadow_color = panel_glow_color
		panel_style.shadow_size = panel_glow_size
		panel_style.shadow_offset = Vector2.ZERO
		panel_style.set_content_margin_all(0.0)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	_apply_label_neon_style(time_label, time_text_color, 19, 1)
	_apply_label_neon_style(phase_label, phase_text_color, 15, 1)

	if bgm_mute_button != null:
		_apply_bgm_mute_button_style(AudioSettings.is_muted(AudioSettings.BUS_BGM))


func _apply_label_neon_style(label: Label, font_color: Color, font_size: int, shadow_outline_size: int) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(panel_border_color.r, panel_border_color.g, panel_border_color.b, 0.55))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", shadow_outline_size)


func _setup_bgm_mute_button() -> void:
	if bgm_mute_button == null:
		return

	bgm_mute_button.toggle_mode = true
	bgm_mute_button.focus_mode = Control.FOCUS_NONE

	if not bgm_mute_button.pressed.is_connected(_on_bgm_mute_button_pressed):
		bgm_mute_button.pressed.connect(_on_bgm_mute_button_pressed)

	if not AudioSettings.volume_changed.is_connected(_on_audio_volume_changed):
		AudioSettings.volume_changed.connect(_on_audio_volume_changed)

	_refresh_bgm_mute_button()


func _apply_bgm_mute_button_style(is_bgm_muted: bool) -> void:
	if bgm_mute_button == null:
		return

	var button_bg_color := Color(0.06, 0.02, 0.03, 0.92) if is_bgm_muted else panel_bg_color
	var button_border_color := Color(1.0, 0.36, 0.42, 0.95) if is_bgm_muted else panel_border_color
	var button_font_color := Color(1.0, 0.72, 0.76, 1.0) if is_bgm_muted else phase_text_color

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = button_bg_color
	normal_style.border_color = button_border_color
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(panel_corner_radius)
	normal_style.shadow_color = Color(button_border_color.r, button_border_color.g, button_border_color.b, 0.35)
	normal_style.shadow_size = 10
	normal_style.shadow_offset = Vector2.ZERO
	normal_style.set_content_margin_all(0.0)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(
		min(button_bg_color.r + 0.04, 1.0),
		min(button_bg_color.g + 0.04, 1.0),
		min(button_bg_color.b + 0.04, 1.0),
		button_bg_color.a
	)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.shadow_size = 14

	bgm_mute_button.add_theme_stylebox_override("normal", normal_style)
	bgm_mute_button.add_theme_stylebox_override("hover", hover_style)
	bgm_mute_button.add_theme_stylebox_override("pressed", pressed_style)
	bgm_mute_button.add_theme_color_override("font_color", button_font_color)
	bgm_mute_button.add_theme_color_override("font_hover_color", button_font_color)
	bgm_mute_button.add_theme_color_override("font_pressed_color", button_font_color)
	bgm_mute_button.add_theme_font_size_override("font_size", 14)


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


func _find_weather() -> GameWeatherSystem:
	if weather_path != NodePath():
		var node := get_node_or_null(weather_path)
		if node is GameWeatherSystem:
			return node

	var autoload_weather := get_node_or_null("/root/WeatherSystem")
	if autoload_weather is GameWeatherSystem:
		return autoload_weather

	var group_nodes := get_tree().get_nodes_in_group("weather_system")
	if group_nodes.size() > 0 and group_nodes[0] is GameWeatherSystem:
		return group_nodes[0]

	return null


func _connect_weather_signals() -> void:
	if _weather == null:
		return
	if not _weather.weather_changed.is_connected(_on_weather_changed):
		_weather.weather_changed.connect(_on_weather_changed)
	if not _weather.daily_weather_updated.is_connected(_on_daily_weather_updated):
		_weather.daily_weather_updated.connect(_on_daily_weather_updated)


func _refresh() -> void:
	if _clock == null:
		return

	time_label.text = _clock.get_day_text()
	phase_label.text = "%s / %s  %s" % [
		_get_weather_display_text(),
		_clock.get_phase_display_name(),
		_clock.get_time_text(),
	]


func _get_weather_display_text() -> String:
	if _weather == null:
		_weather = _find_weather()
		if _weather != null:
			_connect_weather_signals()
	if _weather == null:
		return "天候なし"
	return _weather.get_weather_display_name()


func _refresh_bgm_mute_button() -> void:
	if bgm_mute_button == null:
		return

	var is_bgm_muted := AudioSettings.is_muted(AudioSettings.BUS_BGM)
	bgm_mute_button.set_pressed_no_signal(is_bgm_muted)
	bgm_mute_button.text = "OFF" if is_bgm_muted else "BGM"
	bgm_mute_button.tooltip_text = "BGMミュート解除" if is_bgm_muted else "BGMミュート"
	_apply_bgm_mute_button_style(is_bgm_muted)


func _on_bgm_mute_button_pressed() -> void:
	AudioSettings.toggle_mute(AudioSettings.BUS_BGM)
	_refresh_bgm_mute_button()


func _on_audio_volume_changed(bus_name: StringName, _volume: float) -> void:
	if bus_name != AudioSettings.BUS_BGM:
		return
	_refresh_bgm_mute_button()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_refresh()


func _on_phase_changed(_phase_id: String) -> void:
	_refresh()


func _on_season_changed(_season_id: String, _season_day: int, _season_year: int) -> void:
	_refresh()


func _on_weather_changed(_weather_id: StringName, _display_name: String) -> void:
	_refresh()


func _on_daily_weather_updated(_day: int, _weather_id: StringName, _display_name: String) -> void:
	_refresh()
