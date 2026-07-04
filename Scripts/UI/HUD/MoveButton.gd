extends Button
class_name MoveButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "移動"
@export var move_menu_path: NodePath = NodePath("../MoveMenu")
@export var fallback_group_name: StringName = &"move_menu"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	_apply_square_button_layout()
	text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
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
	custom_minimum_size = Vector2(80.0, 80.0)
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
