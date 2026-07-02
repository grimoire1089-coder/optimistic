extends Button
class_name SettingsButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const HUD_BUTTON_SIZE := Vector2(56.0, 56.0)
const SECOND_ROW_TOP_RIGHT_OFFSET := Vector2(-152.0, 256.0)

@export var label_text: String = "設定"
@export var options_overlay_path: NodePath = NodePath("../GameOptionsOverlay")
@export var fallback_group_name: StringName = &"game_options_overlay"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	add_to_group("settings_button")
	_apply_square_button_layout()
	text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var options_overlay: Node = _find_options_overlay()
	if options_overlay == null:
		push_warning("Game options overlay not found: %s" % options_overlay_path)
		return

	if options_overlay.has_method("open_options"):
		options_overlay.call("open_options")
		return
	if options_overlay.has_method("toggle_options"):
		options_overlay.call("toggle_options")
		return
	if options_overlay is CanvasItem:
		var canvas_item: CanvasItem = options_overlay as CanvasItem
		canvas_item.visible = true


func _find_options_overlay() -> Node:
	var options_overlay: Node = get_node_or_null(options_overlay_path)
	if options_overlay != null:
		return options_overlay
	return get_tree().get_first_node_in_group(fallback_group_name)


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
	custom_minimum_size = HUD_BUTTON_SIZE
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = SECOND_ROW_TOP_RIGHT_OFFSET.x
	offset_top = SECOND_ROW_TOP_RIGHT_OFFSET.y
	offset_right = SECOND_ROW_TOP_RIGHT_OFFSET.x + HUD_BUTTON_SIZE.x
	offset_bottom = SECOND_ROW_TOP_RIGHT_OFFSET.y + HUD_BUTTON_SIZE.y
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 11)
	_add_rounded_button_styles()


func _add_rounded_button_styles() -> void:
	add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.10, 0.12, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	add_theme_stylebox_override("hover", _make_style(Color(0.15, 0.15, 0.18, 0.98), Color(0.00, 1.65, 1.65, 0.95), 2))
	add_theme_stylebox_override("pressed", _make_style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	add_theme_stylebox_override("disabled", _make_style(Color(0.08, 0.08, 0.09, 0.62), Color(0.18, 0.18, 0.20, 0.8), 1))


func _make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3.0)
	return style
