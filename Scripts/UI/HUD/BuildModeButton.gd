extends Button
class_name BuildModeButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_BUILD_ICON_PATH := "res://Assets/UI/Icons/Build_Mode.png"

@export var label_text: String = "ビルド"
@export var active_label_text: String = "ビルド中"
@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var fallback_room_is_buildable: bool = true
@export var click_sfx: AudioStream
@export var build_mode_icon: Texture2D
@export var show_text: bool = false
@export var click_sfx_volume_db: float = 0.0

var _controller: BuildModeController
var _room_map: Node
var _local_enabled := false


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
	_sync_process_enabled()


func _process(_delta: float) -> void:
	_resolve_refs()
	_connect_controller()
	_sync_button_state()
	_sync_process_enabled()


func _on_pressed() -> void:
	_play_click_sfx()
	_set_enabled(button_pressed)
	_sync_button_state()


func _on_build_mode_changed(_enabled: bool) -> void:
	_sync_button_state()


func _on_buildable_changed(_buildable: bool) -> void:
	_sync_button_state()


func refresh_build_state() -> void:
	_sync_button_state()


func _sync_button_state() -> void:
	_resolve_refs()
	_connect_controller()
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


func _sync_process_enabled() -> void:
	set_process(_controller == null or _room_map == null)


func _resolve_refs() -> void:
	if _controller == null and not build_mode_controller_path.is_empty():
		_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path)


func _connect_controller() -> void:
	if _controller == null:
		return
	var build_callable := Callable(self, "_on_build_mode_changed")
	if not _controller.build_mode_changed.is_connected(build_callable):
		_controller.build_mode_changed.connect(build_callable)
	var buildable_callable := Callable(self, "_on_buildable_changed")
	if not _controller.buildable_changed.is_connected(buildable_callable):
		_controller.buildable_changed.connect(buildable_callable)


func _apply_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_BUILD_LEFT)
	)
	HudButtonStyle.apply_icon_button_layout(self)


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
