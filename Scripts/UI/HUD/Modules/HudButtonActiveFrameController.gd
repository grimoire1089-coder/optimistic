extends Node
class_name HudButtonActiveFrameController

const NORMAL_BG := Color(0.10, 0.10, 0.12, 0.95)
const HOVER_BG := Color(0.15, 0.15, 0.18, 0.98)
const PRESSED_BG := Color(0.04, 0.20, 0.22, 1.0)
const DISABLED_BG := Color(0.08, 0.08, 0.09, 0.62)

const NORMAL_BORDER := Color(0.26, 0.28, 0.32, 1.0)
const HOVER_BORDER := Color(0.00, 1.65, 1.65, 0.95)
const PRESSED_BORDER := Color(0.25, 2.4, 2.4, 1.0)
const DISABLED_BORDER := Color(0.18, 0.18, 0.20, 0.8)
const ACTIVE_BORDER := Color(1.0, 0.0, 0.95, 1.0)

const NORMAL_BORDER_WIDTH := 1
const HOVER_BORDER_WIDTH := 2
const PRESSED_BORDER_WIDTH := 2
const DISABLED_BORDER_WIDTH := 1
const ACTIVE_BORDER_WIDTH := 4

const HUD_BUTTON_SIZE := Vector2(80.0, 80.0)
const HUD_BUTTON_GAP := 16.0
const HUD_RIGHT_MARGIN := 24.0
const FIRST_ROW_TOP := 232.0
const FIRST_ROW_BUILD_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)
const FIRST_ROW_INVENTORY_LEFT := FIRST_ROW_BUILD_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_BOOK_LEFT := FIRST_ROW_INVENTORY_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_SHOP_LEFT := FIRST_ROW_BOOK_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const FIRST_ROW_ROBIN_LEFT := FIRST_ROW_SHOP_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_TOP := FIRST_ROW_TOP + HUD_BUTTON_SIZE.y + HUD_BUTTON_GAP
const SECOND_ROW_BILL_LEFT := -(HUD_RIGHT_MARGIN + HUD_BUTTON_SIZE.x)
const SECOND_ROW_SETTINGS_LEFT := SECOND_ROW_BILL_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_CRAFT_LEFT := SECOND_ROW_SETTINGS_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_WORK_LEFT := SECOND_ROW_CRAFT_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP
const SECOND_ROW_MOVE_LEFT := SECOND_ROW_WORK_LEFT - HUD_BUTTON_SIZE.x - HUD_BUTTON_GAP

const BUTTON_TO_UI := {
	"RobinHudButton": "AICharacterHud",
	"ShopButton": "ShopMenu",
	"BookButton": "BookLibraryUI",
	"InventoryButton": "InventoryUI",
	"WorkCreditButton": "WorkMenu",
	"CraftButton": "CraftMenu",
	"SettingsButton": "GameOptionsOverlay",
	"BillButton": "BillPanel",
}

const TOGGLE_STATE_BUTTONS := [
	"BuildModeButton",
]

const BUTTON_LAYOUTS := {
	"RobinHudButton": Vector2(FIRST_ROW_ROBIN_LEFT, FIRST_ROW_TOP),
	"ShopButton": Vector2(FIRST_ROW_SHOP_LEFT, FIRST_ROW_TOP),
	"BookButton": Vector2(FIRST_ROW_BOOK_LEFT, FIRST_ROW_TOP),
	"InventoryButton": Vector2(FIRST_ROW_INVENTORY_LEFT, FIRST_ROW_TOP),
	"BuildModeButton": Vector2(FIRST_ROW_BUILD_LEFT, FIRST_ROW_TOP),
	"MoveButton": Vector2(SECOND_ROW_MOVE_LEFT, SECOND_ROW_TOP),
	"WorkCreditButton": Vector2(SECOND_ROW_WORK_LEFT, SECOND_ROW_TOP),
	"CraftButton": Vector2(SECOND_ROW_CRAFT_LEFT, SECOND_ROW_TOP),
	"SettingsButton": Vector2(SECOND_ROW_SETTINGS_LEFT, SECOND_ROW_TOP),
	"BillButton": Vector2(SECOND_ROW_BILL_LEFT, SECOND_ROW_TOP),
}


func _ready() -> void:
	call_deferred("_connect_and_sync")


func _connect_and_sync() -> void:
	_apply_button_group_layout()
	_connect_open_ui_signals()
	_connect_toggle_state_button_signals()
	_sync_all_button_frames()


func _apply_button_group_layout() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_LAYOUTS.keys():
		var button := parent_node.get_node_or_null(String(button_name)) as Control
		if button == null:
			continue
		_place_top_right_control(button, BUTTON_LAYOUTS[button_name], HUD_BUTTON_SIZE)


func _place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2) -> void:
	control.custom_minimum_size = control_size
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = top_right_offset.x
	control.offset_top = top_right_offset.y
	control.offset_right = top_right_offset.x + control_size.x
	control.offset_bottom = top_right_offset.y + control_size.y


func _connect_open_ui_signals() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_TO_UI.keys():
		var ui_node := parent_node.get_node_or_null(String(BUTTON_TO_UI[button_name]))
		if not (ui_node is CanvasItem):
			continue
		var canvas_item := ui_node as CanvasItem
		var callable := Callable(self, "_on_ui_visibility_changed").bind(String(button_name), canvas_item)
		if not canvas_item.visibility_changed.is_connected(callable):
			canvas_item.visibility_changed.connect(callable)


func _connect_toggle_state_button_signals() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in TOGGLE_STATE_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		if button == null:
			continue
		var callable := Callable(self, "_on_toggle_button_changed").bind(button)
		if not button.toggled.is_connected(callable):
			button.toggled.connect(callable)
		var pressed_callable := Callable(self, "_on_toggle_button_pressed").bind(button)
		if not button.pressed.is_connected(pressed_callable):
			button.pressed.connect(pressed_callable)


func _sync_all_button_frames() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_TO_UI.keys():
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		var ui_node := parent_node.get_node_or_null(String(BUTTON_TO_UI[button_name]))
		_apply_button_frame(button, _is_canvas_item_visible(ui_node))
	for button_name in TOGGLE_STATE_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		_apply_button_frame(button, button != null and button.button_pressed)


func _on_ui_visibility_changed(button_name: String, canvas_item: CanvasItem) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var button := parent_node.get_node_or_null(button_name) as Button
	_apply_button_frame(button, canvas_item.visible)


func _on_toggle_button_changed(_enabled: bool, button: Button) -> void:
	_apply_button_frame(button, button != null and button.button_pressed)


func _on_toggle_button_pressed(button: Button) -> void:
	call_deferred("_sync_toggle_button_frame", button)


func _sync_toggle_button_frame(button: Button) -> void:
	_apply_button_frame(button, button != null and button.button_pressed)


func _is_canvas_item_visible(node: Node) -> bool:
	if node == null:
		return false
	if node is CanvasItem:
		return (node as CanvasItem).visible
	return false


func _apply_button_frame(button: Button, is_active: bool) -> void:
	if button == null:
		return
	if is_active:
		button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("focus", _make_style(HOVER_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("disabled", _make_style(DISABLED_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		return

	button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, NORMAL_BORDER, NORMAL_BORDER_WIDTH))
	button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, HOVER_BORDER, HOVER_BORDER_WIDTH))
	button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, PRESSED_BORDER, PRESSED_BORDER_WIDTH))
	button.add_theme_stylebox_override("focus", _make_style(HOVER_BG, HOVER_BORDER, HOVER_BORDER_WIDTH))
	button.add_theme_stylebox_override("disabled", _make_style(DISABLED_BG, DISABLED_BORDER, DISABLED_BORDER_WIDTH))


func _make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3.0)
	return style
