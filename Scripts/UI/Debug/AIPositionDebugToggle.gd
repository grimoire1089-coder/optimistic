extends Control
class_name AIPositionDebugToggle

const OVERLAY_SCRIPT := preload("res://Scripts/UI/Debug/AIPositionDebugOverlay.gd")

const BUTTON_SIZE := Vector2(64.0, 44.0)
const BUTTON_MARGIN := Vector2(190.0, 24.0)

@export var show_only_in_debug_build: bool = true

var _toggle_button: Button
var _overlay: AIPositionDebugOverlay


func _ready() -> void:
	if show_only_in_debug_build and not OS.is_debug_build():
		visible = false
		set_process(false)
		return
	z_index = 910
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_overlay()
	_build_toggle_button()


func _build_overlay() -> void:
	_overlay = OVERLAY_SCRIPT.new() as AIPositionDebugOverlay
	_overlay.name = "AIPositionDebugOverlay"
	_overlay.visible = false
	_overlay.z_index = 0
	add_child(_overlay)


func _build_toggle_button() -> void:
	_toggle_button = Button.new()
	_toggle_button.name = "AIPositionDebugToggleButton"
	_toggle_button.custom_minimum_size = BUTTON_SIZE
	_toggle_button.size = BUTTON_SIZE
	_toggle_button.toggle_mode = true
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle_button.text = "POS"
	_toggle_button.tooltip_text = "AI表示位置とクリック範囲の可視化を切替"
	_place_bottom_right_control(_toggle_button, BUTTON_MARGIN, BUTTON_SIZE)
	_apply_button_style(_toggle_button)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)


func _on_toggle_pressed() -> void:
	var is_enabled := _toggle_button != null and _toggle_button.button_pressed
	if _overlay != null:
		_overlay.set_debug_visible(is_enabled)
	if _toggle_button != null:
		_toggle_button.text = "POS-" if is_enabled else "POS"


func _place_bottom_right_control(control: Control, margin: Vector2, control_size: Vector2) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = -margin.x - control_size.x
	control.offset_top = -margin.y - control_size.y
	control.offset_right = -margin.x
	control.offset_bottom = -margin.y


func _apply_button_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.035, 0.94)
	style.border_color = Color(0.3, 0.95, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.1, 0.8, 1.0, 0.24)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color(0.72, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 11)
