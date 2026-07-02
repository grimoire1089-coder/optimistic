extends Button
class_name CraftButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_LABEL_CODES := [0x5236, 0x4f5c]
const FIRST_ROW_BUTTON_SIZE := Vector2(48.0, 48.0)
const SECOND_ROW_TOP_RIGHT_OFFSET := Vector2(-280.0, 236.0)
const SECOND_ROW_BUTTON_SIZE := Vector2(48.0, 48.0)
const SECOND_ROW_MENU_TOP_RIGHT_OFFSET := Vector2(-328.0, 304.0)
const SECOND_ROW_MENU_SIZE := Vector2(304.0, 260.0)

@export var label_text: String = ""
@export var craft_menu_path: NodePath = NodePath("../CraftMenu")
@export var fallback_group_name: StringName = &"craft_menu"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	_apply_square_button_layout()
	text = _get_label_text()
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)
	call_deferred("_apply_hud_button_layout_after_parent")


func _on_pressed() -> void:
	_play_click_sfx()
	var craft_menu := _find_craft_menu()
	if craft_menu == null:
		push_warning("Craft menu not found: %s" % craft_menu_path)
		return

	if craft_menu.has_method("toggle_menu"):
		craft_menu.call("toggle_menu")
		return
	if craft_menu.has_method("open_menu"):
		craft_menu.call("open_menu")
		return
	if craft_menu is CanvasItem:
		var canvas_item := craft_menu as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_craft_menu() -> Node:
	var craft_menu := get_node_or_null(craft_menu_path)
	if craft_menu != null:
		return craft_menu
	return get_tree().get_first_node_in_group(fallback_group_name)


func _get_label_text() -> String:
	if not label_text.is_empty():
		return label_text
	return _string_from_codes(DEFAULT_LABEL_CODES)


func _string_from_codes(codes: Array) -> String:
	var value := ""
	for code in codes:
		value += String.chr(int(code))
	return value


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
	custom_minimum_size = Vector2(56.0, 56.0)
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -280.0
	offset_top = 236.0
	offset_right = -224.0
	offset_bottom = 292.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 11)
	_add_rounded_button_styles()


func _apply_hud_button_layout_after_parent() -> void:
	_place_canvas_sibling("RobinHudButton", Vector2(-280.0, 184.0), FIRST_ROW_BUTTON_SIZE)
	_place_canvas_sibling("ShopButton", Vector2(-228.0, 184.0), FIRST_ROW_BUTTON_SIZE)
	_place_canvas_sibling("InventoryButton", Vector2(-176.0, 184.0), FIRST_ROW_BUTTON_SIZE)
	_place_canvas_sibling("BuildModeButton", Vector2(-124.0, 184.0), FIRST_ROW_BUTTON_SIZE)
	_place_canvas_sibling("WorkCreditButton", Vector2(-72.0, 184.0), FIRST_ROW_BUTTON_SIZE)
	_place_top_right_control(self, SECOND_ROW_TOP_RIGHT_OFFSET, SECOND_ROW_BUTTON_SIZE)
	var craft_menu := _find_craft_menu() as Control
	if craft_menu == null:
		return
	_place_top_right_control(craft_menu, SECOND_ROW_MENU_TOP_RIGHT_OFFSET, SECOND_ROW_MENU_SIZE)


func _place_canvas_sibling(node_name: String, top_right_offset: Vector2, control_size: Vector2) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var control := parent_node.get_node_or_null(node_name) as Control
	_place_top_right_control(control, top_right_offset, control_size)


func _place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2) -> void:
	if control == null:
		return
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = top_right_offset.x
	control.offset_top = top_right_offset.y
	control.offset_right = top_right_offset.x + control_size.x
	control.offset_bottom = top_right_offset.y + control_size.y


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