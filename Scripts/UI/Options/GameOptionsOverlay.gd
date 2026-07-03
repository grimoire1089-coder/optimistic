extends Control
class_name GameOptionsOverlay

const DISPLAY_MODE_FULLSCREEN := 0
const DISPLAY_MODE_BORDERLESS_WINDOW := 1
const DISPLAY_MODE_WINDOWED := 2
const WINDOWED_BASE_SIZE := Vector2i(1920, 1080)
const WINDOWED_SCREEN_MARGIN := Vector2i(160, 120)
const WINDOWED_MIN_SIZE := Vector2i(960, 540)

@export var settings_tabs_path: NodePath = NodePath("CenterContainer/OverlayBox/SettingsTabs")
@export var display_mode_option_path: NodePath = NodePath("CenterContainer/OverlayBox/SettingsTabs/GraphicsPage/MarginContainer/Rows/DisplayModeRow/DisplayModeOption")
@export var close_button_path: NodePath = NodePath("CenterContainer/OverlayBox/CloseOptionsButton")
@export var quit_button_path: NodePath = NodePath("CenterContainer/OverlayBox/QuitGameButton")
@export var pause_scene_tree: bool = true
@export var pause_game_clock: bool = true

var _settings_tabs: TabContainer
var _display_mode_option: OptionButton
var _close_button: Button
var _quit_button: Button
var _game_clock: Node
var _was_tree_paused: bool = false
var _has_saved_tree_pause: bool = false
var _was_clock_paused: bool = false
var _has_saved_clock_pause: bool = false


func _ready() -> void:
	add_to_group("game_options_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_process_mode_recursive(self, Node.PROCESS_MODE_ALWAYS)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_resolve_refs()
	_setup_tabs()
	_setup_display_mode_option()
	_connect_close_button()
	_connect_quit_button()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_options()
		get_viewport().set_input_as_handled()


func open_options() -> void:
	if visible:
		return

	_resolve_refs()
	_sync_display_mode_option()
	_save_pause_state()
	visible = true
	move_to_front()
	_pause_game()

	if _close_button != null:
		_close_button.grab_focus()


func close_options() -> void:
	if not visible:
		return

	visible = false
	_restore_pause_state()


func quit_game() -> void:
	if visible:
		visible = false
	_restore_pause_state()
	get_tree().quit()


func toggle_options() -> void:
	if visible:
		close_options()
	else:
		open_options()


func _exit_tree() -> void:
	if visible:
		_restore_pause_state()


func _save_pause_state() -> void:
	_was_tree_paused = get_tree().paused
	_has_saved_tree_pause = true

	_game_clock = get_node_or_null("/root/GameClock")
	if _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_was_clock_paused = bool(_game_clock.get("is_clock_paused"))
		_has_saved_clock_pause = true


func _pause_game() -> void:
	if pause_game_clock and _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_game_clock.call("set_clock_paused", true)

	if pause_scene_tree:
		get_tree().paused = true


func _restore_pause_state() -> void:
	if pause_game_clock and _has_saved_clock_pause and _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_game_clock.call("set_clock_paused", _was_clock_paused)

	if pause_scene_tree and _has_saved_tree_pause:
		get_tree().paused = _was_tree_paused

	_has_saved_clock_pause = false
	_has_saved_tree_pause = false


func _resolve_refs() -> void:
	if _settings_tabs == null and not settings_tabs_path.is_empty():
		_settings_tabs = get_node_or_null(settings_tabs_path) as TabContainer
	if _display_mode_option == null and not display_mode_option_path.is_empty():
		_display_mode_option = get_node_or_null(display_mode_option_path) as OptionButton
	if _close_button == null and not close_button_path.is_empty():
		_close_button = get_node_or_null(close_button_path) as Button
	if _quit_button == null and not quit_button_path.is_empty():
		_quit_button = get_node_or_null(quit_button_path) as Button


func _setup_tabs() -> void:
	if _settings_tabs == null:
		return
	if _settings_tabs.get_tab_count() >= 1:
		_settings_tabs.set_tab_title(0, "グラフィック")
	if _settings_tabs.get_tab_count() >= 2:
		_settings_tabs.set_tab_title(1, "サウンド")


func _setup_display_mode_option() -> void:
	if _display_mode_option == null:
		return
	if _display_mode_option.get_item_count() <= 0:
		_display_mode_option.add_item("フルスクリーン", DISPLAY_MODE_FULLSCREEN)
		_display_mode_option.add_item("ボーダーレスウィンドウ", DISPLAY_MODE_BORDERLESS_WINDOW)
		_display_mode_option.add_item("ウィンドウ", DISPLAY_MODE_WINDOWED)
	if not _display_mode_option.item_selected.is_connected(_on_display_mode_selected):
		_display_mode_option.item_selected.connect(_on_display_mode_selected)
	_sync_display_mode_option()


func _connect_close_button() -> void:
	if _close_button == null:
		return
	if not _close_button.pressed.is_connected(close_options):
		_close_button.pressed.connect(close_options)


func _connect_quit_button() -> void:
	if _quit_button == null:
		return
	if not _quit_button.pressed.is_connected(quit_game):
		_quit_button.pressed.connect(quit_game)


func _on_display_mode_selected(index: int) -> void:
	if _display_mode_option == null:
		return
	var mode_id := _display_mode_option.get_item_id(index)
	_apply_display_mode(mode_id)


func _sync_display_mode_option() -> void:
	if _display_mode_option == null:
		return
	var current_mode_id := _get_current_display_mode_id()
	for index in range(_display_mode_option.get_item_count()):
		if _display_mode_option.get_item_id(index) == current_mode_id:
			_display_mode_option.select(index)
			return


func _get_current_display_mode_id() -> int:
	var window_mode := DisplayServer.window_get_mode()
	if window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	if window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return DISPLAY_MODE_FULLSCREEN
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return DISPLAY_MODE_BORDERLESS_WINDOW
	return DISPLAY_MODE_WINDOWED


func _apply_display_mode(mode_id: int) -> void:
	var screen := DisplayServer.window_get_current_screen()
	match mode_id:
		DISPLAY_MODE_FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DISPLAY_MODE_BORDERLESS_WINDOW:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		DISPLAY_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_centered_window_size(screen)
		_:
			return


func _apply_centered_window_size(screen: int) -> void:
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var window_size := _get_windowed_size_for_screen(screen_size)
	var window_position := screen_position + Vector2i(
		int(round(float(screen_size.x - window_size.x) * 0.5)),
		int(round(float(screen_size.y - window_size.y) * 0.5))
	)
	DisplayServer.window_set_size(window_size)
	DisplayServer.window_set_position(window_position)


func _get_windowed_size_for_screen(screen_size: Vector2i) -> Vector2i:
	var max_size := Vector2i(
		maxi(screen_size.x - WINDOWED_SCREEN_MARGIN.x, WINDOWED_MIN_SIZE.x),
		maxi(screen_size.y - WINDOWED_SCREEN_MARGIN.y, WINDOWED_MIN_SIZE.y)
	)
	var scale := minf(
		1.0,
		minf(
			float(max_size.x) / float(WINDOWED_BASE_SIZE.x),
			float(max_size.y) / float(WINDOWED_BASE_SIZE.y)
		)
	)
	return Vector2i(
		maxi(int(round(float(WINDOWED_BASE_SIZE.x) * scale)), WINDOWED_MIN_SIZE.x),
		maxi(int(round(float(WINDOWED_BASE_SIZE.y) * scale)), WINDOWED_MIN_SIZE.y)
	)


func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	if node == null:
		return
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)
