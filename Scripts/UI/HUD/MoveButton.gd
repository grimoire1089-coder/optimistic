extends Button
class_name MoveButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_MOVE_ICON_PATH := "res://Assets/UI/Icons/Move.png"
const LOCKED_MESSAGE := "今は使えません。"
const MOVEMENT_LOCK_ACTION_IDS := [
	&"map_travel",
	&"part_time_work",
]

@export var label_text: String = "移動"
@export var move_menu_path: NodePath = NodePath("../MoveMenu")
@export var work_menu_path: NodePath = NodePath("../WorkMenu")
@export var fallback_group_name: StringName = &"move_menu"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var move_icon: Texture2D


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_move_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	elif text.is_empty():
		text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if _is_movement_locked():
		_push_message(LOCKED_MESSAGE)
		return
	_play_click_sfx()
	var move_menu := _find_move_menu()
	if move_menu == null:
		push_warning("Move menu not found: %s" % move_menu_path)
		return
	if move_menu.has_method("toggle_menu"):
		move_menu.call("toggle_menu")
		return
	if move_menu.has_method("open_menu"):
		move_menu.call("open_menu")
		return
	if move_menu is CanvasItem:
		var canvas_item := move_menu as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_move_menu() -> Node:
	var move_menu := get_node_or_null(move_menu_path)
	if move_menu != null:
		return move_menu
	return get_tree().get_first_node_in_group(fallback_group_name)


func _is_movement_locked() -> bool:
	var move_menu := _find_move_menu()
	if move_menu != null and move_menu.get("_is_map_move_processing") == true:
		return true
	var work_menu := get_node_or_null(work_menu_path)
	if work_menu != null:
		if work_menu.has_method("is_work_processing") and work_menu.call("is_work_processing") == true:
			return true
		if work_menu.get("_is_work_processing") == true:
			return true
	var robin := _find_robin_actor()
	if robin == null or not robin.has_method("get_current_need_action_id"):
		return false
	var action_id_value: Variant = robin.call("get_current_need_action_id")
	var action_id: StringName = &""
	if action_id_value is StringName:
		action_id = action_id_value
	else:
		action_id = StringName(String(action_id_value))
	return MOVEMENT_LOCK_ACTION_IDS.has(action_id)


func _find_robin_actor() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Robin")


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log") as MessageLogPanel
	if message_log == null:
		return
	message_log.add_message(message)


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_move_icon_if_needed() -> void:
	if move_icon == null and icon != null:
		move_icon = icon
	if move_icon == null and ResourceLoader.exists(DEFAULT_MOVE_ICON_PATH):
		move_icon = load(DEFAULT_MOVE_ICON_PATH) as Texture2D
	if move_icon != null:
		icon = move_icon


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_MOVE_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
