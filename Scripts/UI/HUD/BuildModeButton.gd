extends Button
class_name BuildModeButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "ビルド"
@export var active_label_text: String = "ビルド中"
@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var fallback_room_is_buildable: bool = true
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0

var _build_mode_controller: BuildModeController
var _room_map: Node
var _local_build_mode_enabled: bool = false


func _ready() -> void:
	toggle_mode = true
	_apply_square_button_layout()
	_load_default_click_sfx_if_needed()
	_resolve_refs()
	_connect_controller_signals()
	_sync_button_state()
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	_sync_button_state()


func _on_pressed() -> void:
	_play_click_sfx()
	_resolve_refs()
	if not _can_build_in_current_room():
		_set_build_mode_enabled(false)
		return

	_set_build_mode_enabled(button_pressed)
	_sync_button_state()


func _on_build_mode_changed(_enabled: bool) -> void:
	_sync_button_state()


func _sync_button_state() -> void:
	_resolve_refs()
	var can_build := _can_build_in_current_room()
	disabled = not can_build

	if not can_build:
		button_pressed = false
		text = label_text
		tooltip_text = "この場所ではビルドできません"
		return

	if _is_build_mode_enabled():
		button_pressed = true
		text = active_label_text
		tooltip_text = "ビルドモード中"
	else:
		button_pressed = false
		text = label_text
		tooltip_text = "ビルドモードを開始"


func _can_build_in_current_room() -> bool:
	if _build_mode_controller != null:
		return _build_mode_controller.is_buildable()
	if _room_map == null:
		return fallback_room_is_buildable
	if _room_map.has_method("is_buildable"):
		return _room_map.call("is_buildable") == true
	if _room_map.has_meta("buildable"):
		return _room_map.get_meta("buildable", fallback_room_is_buildable) == true
	return fallback_room_is_buildable


func _is_build_mode_enabled() -> bool:
	if _build_mode_controller != null:
		return _build_mode_controller.is_build_mode_enabled()
	if _room_map != null and _room_map.has_method("is_build_mode_enabled"):
		return _room_map.call("is_build_mode_enabled") == true
	return _local_build_mode_enabled


func _set_build_mode_enabled(enabled: bool) -> void:
	var next_enabled := enabled and _can_build_in_current_room()
	if _build_mode_controller != null:
		_build_mode_controller.set_build_mode_enabled(next_enabled)
	elif _room_map != null and _room_map.has_method("set_build_mode_enabled"):
		_room_map.call("set_build_mode_enabled", next_enabled)
	else:
		_local_build_mode_enabled = next_enabled
	button_pressed = next_enabled


func _connect_controller_signals() -> void:
	if _build_mode_controller == null:
		return
	var callable := Callable(self, "_on_build_mode_changed")
	if not _build_mode_controller.build_mode_changed.is_connected(callable):
		_build_mode_controller.build_mode_changed.connect(callable)


func _resolve_refs() -> void:
	if _build_mode_controller == null and not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
		_connect_controller_signals()
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path)


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _apply_square_button_layout() -> void:
	custom_minimum_size = Vector2(72.0, 72.0)
	offset_left = -184.0
	offset_top = -96.0
	offset_right = -112.0
	offset_bottom = -24.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_add_rounded_button_styles()


func _add_rounded_button_styles() -> void:
	add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.10, 0.12, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	add_theme_stylebox_override("hover", _make_style(Color(0.15, 0.15, 0.18, 0.98), Color(0.00, 1.65, 1.65, 0.95), 2))
	add_theme_stylebox_override("pressed", _make_style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	add_theme_stylebox_override("disabled", _make_style(Color(0.08, 0.08, 0.09, 0.62), Color(0.18, 0.18, 0.20, 0.8), 1))
	add_theme_font_size_override("font_size", 13)


func _make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4.0)
	return style
