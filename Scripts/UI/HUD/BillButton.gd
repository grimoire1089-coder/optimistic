extends Button
class_name BillButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const HUD_BUTTON_SIZE := Vector2(56.0, 56.0)
const SECOND_ROW_TOP_RIGHT_OFFSET := Vector2(-80.0, 256.0)

@export var bill_panel_path: NodePath = NodePath("../BillPanel")
@export var fallback_group_name: StringName = &"bill_ui"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	_apply_square_button_layout()
	if text.is_empty() and icon == null:
		text = "請求"
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var bill_panel := _find_bill_panel()
	if bill_panel == null:
		push_warning("Bill panel not found: %s" % bill_panel_path)
		return

	if bill_panel.has_method("toggle_bill_panel"):
		bill_panel.call("toggle_bill_panel")
		return
	if bill_panel.has_method("toggle"):
		bill_panel.call("toggle")
		return
	if bill_panel.has_method("open"):
		bill_panel.call("open")
		return
	if bill_panel is CanvasItem:
		var canvas_item := bill_panel as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_bill_panel() -> Node:
	var bill_panel := get_node_or_null(bill_panel_path)
	if bill_panel != null:
		return bill_panel
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
	expand_icon = true
	add_theme_font_size_override("font_size", 11)
	_add_rounded_button_styles()


func _add_rounded_button_styles() -> void:
	add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.10, 0.12, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	add_theme_stylebox_override("hover", _make_style(Color(0.15, 0.15, 0.18, 0.98), Color(0.00, 1.65, 1.65, 0.95), 2))
	add_theme_stylebox_override("pressed", _make_style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	add_theme_stylebox_override("disabled", _make_style(Color(0.08, 0.08, 0.09, 0.62), Color(0.18, 0.18, 0.20, 0.8), 1))


func _make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3.0)
	return style
