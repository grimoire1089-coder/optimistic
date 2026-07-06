extends RefCounted
class_name HudButtonStyle

const HUD_BUTTON_SIZE := Vector2(80.0, 80.0)
const HUD_BUTTON_GAP := 16.0
const HUD_RIGHT_MARGIN := 24.0
const HUD_ICON_MAX_WIDTH := 64
const HUD_FONT_SIZE := 11
const HUD_CORNER_RADIUS := 8
const HUD_CONTENT_MARGIN := 3.0

const FIRST_ROW_TOP := 232.0
const SECOND_ROW_TOP := FIRST_ROW_TOP + HUD_BUTTON_SIZE.y + HUD_BUTTON_GAP
const THIRD_ROW_TOP := SECOND_ROW_TOP + HUD_BUTTON_SIZE.y + HUD_BUTTON_GAP

const FIRST_ROW_BUILD_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)
const FIRST_ROW_INVENTORY_LEFT := FIRST_ROW_BUILD_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_BOOK_LEFT := FIRST_ROW_INVENTORY_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_SHOP_LEFT := FIRST_ROW_BOOK_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_ROBIN_LEFT := FIRST_ROW_SHOP_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP

const SECOND_ROW_BILL_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)
const SECOND_ROW_SETTINGS_LEFT := SECOND_ROW_BILL_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_CRAFT_LEFT := SECOND_ROW_SETTINGS_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_WORK_LEFT := SECOND_ROW_CRAFT_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_MOVE_LEFT := SECOND_ROW_WORK_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP

const THIRD_ROW_PLACEHOLDER_05_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)
const THIRD_ROW_PLACEHOLDER_04_LEFT := THIRD_ROW_PLACEHOLDER_05_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const THIRD_ROW_PLACEHOLDER_03_LEFT := THIRD_ROW_PLACEHOLDER_04_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const THIRD_ROW_PLACEHOLDER_02_LEFT := THIRD_ROW_PLACEHOLDER_03_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const THIRD_ROW_PLACEHOLDER_01_LEFT := THIRD_ROW_PLACEHOLDER_02_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP

const SECOND_ROW_MENU_TOP_RIGHT_OFFSET := Vector2(-344.0, 328.0)
const SECOND_ROW_MENU_SIZE := Vector2(320.0, 260.0)


static func first_row_offset(left: float) -> Vector2:
	return Vector2(left, FIRST_ROW_TOP)


static func second_row_offset(left: float) -> Vector2:
	return Vector2(left, SECOND_ROW_TOP)


static func third_row_offset(left: float) -> Vector2:
	return Vector2(left, THIRD_ROW_TOP)


static func apply_square_button_visual(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = HUD_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	apply_rounded_button_styles(button)


static func apply_square_button_layout(button: Button, top_right_offset: Vector2, control_size: Vector2 = HUD_BUTTON_SIZE) -> void:
	place_top_right_control(button, top_right_offset, control_size)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	apply_rounded_button_styles(button)


static func apply_icon_button_layout(button: Button, icon_max_width: int = HUD_ICON_MAX_WIDTH) -> void:
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", icon_max_width)
	button.add_theme_constant_override("h_separation", 0)


static func place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2 = HUD_BUTTON_SIZE) -> void:
	if control == null:
		return
	control.custom_minimum_size = control_size
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = top_right_offset.x
	control.offset_top = top_right_offset.y
	control.offset_right = top_right_offset.x + control_size.x
	control.offset_bottom = top_right_offset.y + control_size.y


static func place_bottom_right_control(control: Control, bottom_right_margin: Vector2, control_size: Vector2) -> void:
	if control == null:
		return
	control.custom_minimum_size = control_size
	control.anchor_left = 1.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = -bottom_right_margin.x - control_size.x
	control.offset_top = -bottom_right_margin.y - control_size.y
	control.offset_right = -bottom_right_margin.x
	control.offset_bottom = -bottom_right_margin.y


static func apply_rounded_button_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_style(Color(0.10, 0.10, 0.12, 0.95), Color(0.26, 0.28, 0.32, 1.0), 1))
	button.add_theme_stylebox_override("hover", make_style(Color(0.15, 0.15, 0.18, 0.98), Color(0.00, 1.65, 1.65, 0.95), 2))
	button.add_theme_stylebox_override("pressed", make_style(Color(0.04, 0.20, 0.22, 1.0), Color(0.25, 2.4, 2.4, 1.0), 2))
	button.add_theme_stylebox_override("disabled", make_style(Color(0.08, 0.08, 0.09, 0.62), Color(0.18, 0.18, 0.20, 0.8), 1))


static func make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(HUD_CORNER_RADIUS)
	style.set_content_margin_all(HUD_CONTENT_MARGIN)
	return style
