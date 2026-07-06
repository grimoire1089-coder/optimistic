extends Button
class_name WorkCreditButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_WORK_ICON_PATH := "res://Assets/UI/Icons/Work.png"
const MOVEMENT_LOCK_ACTION_IDS := [
	&"map_travel",
	&"part_time_work",
]

@export var label_text: String = "仕事"
@export var work_menu_path: NodePath = NodePath("../WorkMenu")
@export var move_menu_path: NodePath = NodePath("../MoveMenu")
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var work_icon: Texture2D


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_work_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	elif text.is_empty():
		text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if _is_movement_locked():
		return
	_play_click_sfx()
	var work_menu := get_node_or_null(work_menu_path) as WorkMenu
	if work_menu == null:
		push_warning("Work menu not found: %s" % work_menu_path)
		return

	work_menu.toggle_menu()


func _is_movement_locked() -> bool:
	var move_menu := get_node_or_null(move_menu_path)
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


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_work_icon_if_needed() -> void:
	if work_icon == null and icon != null:
		work_icon = icon
	if work_icon == null and ResourceLoader.exists(DEFAULT_WORK_ICON_PATH):
		work_icon = load(DEFAULT_WORK_ICON_PATH) as Texture2D
	if work_icon != null:
		icon = work_icon


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_WORK_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
