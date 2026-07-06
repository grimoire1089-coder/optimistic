extends Button
class_name BuildModeButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_BUILD_ICON_PATH := "res://Assets/UI/Icons/Build_Mode.png"
const HUD_BUTTON_SIZE := Vector2(80.0, 80.0)
const HUD_ICON_MAX_WIDTH := 68
const HUD_RIGHT_MARGIN := 24.0
const FIRST_ROW_TOP := 184.0
const FIRST_ROW_BUILD_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)

@export var label_text: String = "ビルド"
@export var active_label_text: String = "ビルド中"
@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var fallback_room_is_buildable: bool = true
@export var click_sfx: AudioStream
@export var build_mode_icon: Texture2D
@export var show_text: bool = false
@export var click_sfx_volume_db: float = 0.0
@export var state_poll_interval_seconds: float = 0.25

var _controller: BuildModeController
var _room_map: Node
var _local_enabled := false
var _state_poll_timer := 0.0


func _ready() -> void:
	toggle_mode = true
	_apply_layout()
	_load_default_build_icon_if_needed()
	_controller = BuildUiRuntime.setup(self, fallback_room_is_buildable)
	_resolve_refs()
	_connect_controller()
	_load_default_click_sfx_if_needed()
	_sync_button_state()
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	_state_poll_timer -= maxf(delta, 0.0)
	if _state_poll_timer > 0.0:
		return
	_state_poll_timer = maxf(state_poll_interval_seconds, 0.05)
	_sync_button_state()


func _on_pressed() -> void:
	_play_click_sfx()
	_set_enabled(button_pressed)
	_sync_button_state()


func _on_build_mode_changed(_enabled: bool) -> void:
	_sync_button_state()


func _sync_button_state() -> void:
	_resolve_refs()
	var can_build := _can_build()
	disabled = not can_build
	if not can_build:
		button_pressed = false
		text = label_text if show_text else ""
		tooltip_text = "Build is unavailable here"
		return
	button_pressed = _is_enabled()
	var next_text := active_label_text if button_pressed else label_text
	text = next_text if show_text else ""
	tooltip_text = "Build mode is active" if button_pressed else "Start build mode"


func _can_build() -> bool:
	if _controller != null:
		return _controller.is_buildable()
	if _room_map == null:
		return fallback_room_is_buildable
	if _room_map.has_method("is_buildable"):
		return _room_map.call("is_buildable") == true
	return fallback_room_is_buildable


func _is_enabled() -> bool:
	if _controller != null:
		return _controller.is_build_mode_enabled()
	return _local_enabled


func _set_enabled(enabled: bool) -> void:
	var next_enabled := enabled and _can_build()
	if _controller != null:
		_controller.set_build_mode_enabled(next_enabled)
	else:
		_local_enabled = next_enabled
	button_pressed = next_enabled


func _resolve_refs() -> void:
	if _controller == null and not build_mode_controller_path.is_empty():
		_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path)


func _connect_controller() -> void:
	if _controller == null:
		return
	var callable := Callable(self, "_on_build_mode_changed")
	if not _controller.build_mode_changed.is_connected(callable):
		_controller.build_mode_changed.connect(callable)


func _apply_layout() -> void:
	custom_minimum_size = HUD_BUTTON_SIZE
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = FIRST_ROW_BUILD_LEFT
	offset_top = FIRST_ROW_TOP
	offset_right = FIRST_ROW_BUILD_LEFT + HUD_BUTTON_SIZE.x
	offset_bottom = FIRST_ROW_TOP + HUD_BUTTON_SIZE.y
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 11)
	add_theme_constant_override("icon_max_width", HUD_ICON_MAX_WIDTH)
	add_theme_constant_override("h_separation", 0)
	add_theme_stylebox_override("normal", _style(Color(0.10, 0.10, 0.12, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	add_theme_stylebox_override("hover", _style(Color(0.15, 0.15, 0.18, 0.98), Color(0.0, 1.65, 1.65, 0.95), 2))
	add_theme_stylebox_override("pressed", _style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	add_theme_stylebox_override("disabled", _style(Color(0.08, 0.08, 0.09, 0.62), Color(0.18, 0.18, 0.20, 0.8), 1))


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3.0)
	return style


func _play_click_sfx() -> void:
	if click_sfx != null:
		AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx == null and ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_build_icon_if_needed() -> void:
	if build_mode_icon == null and ResourceLoader.exists(DEFAULT_BUILD_ICON_PATH):
		build_mode_icon = load(DEFAULT_BUILD_ICON_PATH) as Texture2D
	if build_mode_icon != null:
		icon = build_mode_icon
