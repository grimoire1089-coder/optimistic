extends Control
class_name GameOptionsOverlay

@export var close_button_path: NodePath = NodePath("CenterContainer/OverlayBox/CloseOptionsButton")
@export var pause_scene_tree: bool = true
@export var pause_game_clock: bool = true

var _close_button: Button
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
	_connect_close_button()
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
	if _close_button == null and not close_button_path.is_empty():
		_close_button = get_node_or_null(close_button_path) as Button


func _connect_close_button() -> void:
	if _close_button == null:
		return
	if not _close_button.pressed.is_connected(close_options):
		_close_button.pressed.connect(close_options)


func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	if node == null:
		return
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)
