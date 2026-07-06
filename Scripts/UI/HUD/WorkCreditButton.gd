extends Button
class_name WorkCreditButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_WORK_ICON_PATH := "res://Assets/UI/Icons/Work.png"

@export var label_text: String = "仕事"
@export var work_menu_path: NodePath = NodePath("../WorkMenu")
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
	_play_click_sfx()
	var work_menu := get_node_or_null(work_menu_path) as WorkMenu
	if work_menu == null:
		push_warning("Work menu not found: %s" % work_menu_path)
		return

	work_menu.toggle_menu()


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
