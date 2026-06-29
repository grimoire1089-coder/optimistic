extends Button
class_name InventoryButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var inventory_ui_path: NodePath = NodePath("../InventoryUI")
@export var fallback_group_name: StringName = &"inventory_ui"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var inventory_ui := _find_inventory_ui()
	if inventory_ui == null:
		push_warning("Inventory UI not found: %s" % inventory_ui_path)
		return

	_open_or_toggle_inventory(inventory_ui)


func _find_inventory_ui() -> Node:
	var inventory_ui := get_node_or_null(inventory_ui_path)
	if inventory_ui != null:
		return inventory_ui

	return get_tree().get_first_node_in_group(fallback_group_name)


func _open_or_toggle_inventory(inventory_ui: Node) -> void:
	if inventory_ui.has_method("toggle_inventory"):
		inventory_ui.call("toggle_inventory")
		return

	if inventory_ui.has_method("toggle"):
		inventory_ui.call("toggle")
		return

	if inventory_ui.has_method("open"):
		inventory_ui.call("open")
		return

	if inventory_ui is CanvasItem:
		var canvas_item := inventory_ui as CanvasItem
		canvas_item.visible = not canvas_item.visible
		return

	push_warning("No inventory open method found: %s" % inventory_ui.name)


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
	custom_minimum_size = Vector2(72.0, 72.0)
	offset_left = -272.0
	offset_top = -96.0
	offset_right = -200.0
	offset_bottom = -24.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	style.set_content_margin_all(4.0)
	return style
