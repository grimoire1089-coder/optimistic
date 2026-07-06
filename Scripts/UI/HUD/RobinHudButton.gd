extends Button
class_name RobinHudButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_AI_CHARACTER_ICON_PATH := "res://Assets/UI/Icons/AI_Character.png"

@export var label_text: String = "ロビン"
@export var ai_hud_path: NodePath = NodePath("../AICharacterHud")
@export var robin_path: NodePath = NodePath("../../Robin")
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var ai_character_icon: Texture2D


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_ai_character_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	elif text.is_empty():
		text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()

	var ai_hud := get_node_or_null(ai_hud_path) as AICharacterHud
	if ai_hud == null:
		push_warning("AI character HUD not found: %s" % ai_hud_path)
		return

	var robin := get_node_or_null(robin_path) as RobinWanderActor
	if robin == null:
		push_warning("Robin actor not found: %s" % robin_path)
		return

	ai_hud.toggle_actor(robin)


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_ai_character_icon_if_needed() -> void:
	if ai_character_icon == null and icon != null:
		ai_character_icon = icon
	if ai_character_icon == null and ResourceLoader.exists(DEFAULT_AI_CHARACTER_ICON_PATH):
		ai_character_icon = load(DEFAULT_AI_CHARACTER_ICON_PATH) as Texture2D
	if ai_character_icon != null:
		icon = ai_character_icon


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_ROBIN_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
