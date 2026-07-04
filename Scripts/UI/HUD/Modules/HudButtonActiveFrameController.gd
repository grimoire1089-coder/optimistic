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

const BUTTON_TO_UI := {
	"RobinHudButton": "AICharacterHud",
	"ShopButton": "ShopMenu",
	"BookButton": "BookLibraryUI",
	"InventoryButton": "InventoryUI",
	"WorkCreditButton": "WorkMenu",
	"CraftButton": "CraftMenu",
	"SettingsButton": "GameOptionsOverlay",
}

const TOGGLE_STATE_BUTTONS := [
	"BuildModeButton",
]


func _process(_delta: float) -> void:
	_sync_open_ui_buttons()
	_sync_toggle_state_buttons()


func _sync_open_ui_buttons() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_TO_UI.keys():
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		var ui_node := parent_node.get_node_or_null(String(BUTTON_TO_UI[button_name]))
		_apply_button_frame(button, _is_canvas_item_visible(ui_node))


func _sync_toggle_state_buttons() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in TOGGLE_STATE_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
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
