extends Button
class_name CraftButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_LABEL_CODES := [0x5236, 0x4f5c]

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
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_CRAFT_LEFT)
	)


func _apply_hud_button_layout_after_parent() -> void:
	_place_canvas_sibling("RobinHudButton", HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_ROBIN_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("ShopButton", HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_SHOP_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("BookButton", HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_BOOK_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("InventoryButton", HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_INVENTORY_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("BuildModeButton", HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_BUILD_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("WorkCreditButton", HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_WORK_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_top_right_control(self, HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_CRAFT_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("SettingsButton", HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_SETTINGS_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	_place_canvas_sibling("BillButton", HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_BILL_LEFT), HudButtonStyle.HUD_BUTTON_SIZE)
	var craft_menu := _find_craft_menu() as Control
	if craft_menu == null:
		return
	_place_top_right_control(craft_menu, HudButtonStyle.SECOND_ROW_MENU_TOP_RIGHT_OFFSET, HudButtonStyle.SECOND_ROW_MENU_SIZE)


func _place_canvas_sibling(node_name: String, top_right_offset: Vector2, control_size: Vector2) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var control := parent_node.get_node_or_null(node_name) as Control
	_place_top_right_control(control, top_right_offset, control_size)


func _place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2) -> void:
	HudButtonStyle.place_top_right_control(control, top_right_offset, control_size)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
