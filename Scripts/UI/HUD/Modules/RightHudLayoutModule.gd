extends RefCounted
class_name RightHudLayoutModule

const RIGHT_PANEL_MARGIN := Vector2(24.0, 92.0)
const AI_CHARACTER_HUD_SIZE := Vector2(480.0, 456.0)
const AI_CHARACTER_NEED_BAR_WIDTH := 290.0
const INVENTORY_UI_SIZE := Vector2(436.0, 420.0)
const WORK_MENU_SIZE := Vector2(356.0, 196.0)
const BOOK_LIBRARY_UI_SIZE := Vector2(420.0, 456.0)
const BILL_PANEL_SIZE := Vector2(420.0, 456.0)
const CRAFT_MENU_POSITION := Vector2(-328.0, 252.0)
const CRAFT_MENU_SIZE := Vector2(304.0, 172.0)

const PASSIVE_FRAME_BUTTONS := [
	"PlaceholderHudButton01",
	"PlaceholderHudButton02",
	"PlaceholderHudButton03",
	"PlaceholderHudButton05",
]

const BUTTON_LAYOUTS := {
	"RobinHudButton": Vector2(HudButtonStyle.FIRST_ROW_ROBIN_LEFT, HudButtonStyle.FIRST_ROW_TOP),
	"ShopButton": Vector2(HudButtonStyle.FIRST_ROW_SHOP_LEFT, HudButtonStyle.FIRST_ROW_TOP),
	"BookButton": Vector2(HudButtonStyle.FIRST_ROW_BOOK_LEFT, HudButtonStyle.FIRST_ROW_TOP),
	"InventoryButton": Vector2(HudButtonStyle.FIRST_ROW_INVENTORY_LEFT, HudButtonStyle.FIRST_ROW_TOP),
	"BuildModeButton": Vector2(HudButtonStyle.FIRST_ROW_BUILD_LEFT, HudButtonStyle.FIRST_ROW_TOP),
	"MoveButton": Vector2(HudButtonStyle.SECOND_ROW_MOVE_LEFT, HudButtonStyle.SECOND_ROW_TOP),
	"WorkCreditButton": Vector2(HudButtonStyle.SECOND_ROW_WORK_LEFT, HudButtonStyle.SECOND_ROW_TOP),
	"CraftButton": Vector2(HudButtonStyle.SECOND_ROW_CRAFT_LEFT, HudButtonStyle.SECOND_ROW_TOP),
	"SettingsButton": Vector2(HudButtonStyle.THIRD_ROW_PLACEHOLDER_05_LEFT, HudButtonStyle.THIRD_ROW_TOP),
	"BillButton": Vector2(HudButtonStyle.SECOND_ROW_BILL_LEFT, HudButtonStyle.SECOND_ROW_TOP),
	"PlaceholderHudButton01": Vector2(HudButtonStyle.THIRD_ROW_PLACEHOLDER_01_LEFT, HudButtonStyle.THIRD_ROW_TOP),
	"PlaceholderHudButton02": Vector2(HudButtonStyle.THIRD_ROW_PLACEHOLDER_02_LEFT, HudButtonStyle.THIRD_ROW_TOP),
	"PlaceholderHudButton03": Vector2(HudButtonStyle.THIRD_ROW_PLACEHOLDER_03_LEFT, HudButtonStyle.THIRD_ROW_TOP),
	"EncyclopediaButton": Vector2(HudButtonStyle.THIRD_ROW_PLACEHOLDER_04_LEFT, HudButtonStyle.THIRD_ROW_TOP),
	"PlaceholderHudButton05": Vector2(HudButtonStyle.SECOND_ROW_SETTINGS_LEFT, HudButtonStyle.SECOND_ROW_TOP),
}

const RIGHT_PANEL_LAYOUTS := {
	"AICharacterHud": AI_CHARACTER_HUD_SIZE,
	"InventoryUI": INVENTORY_UI_SIZE,
	"WorkMenu": WORK_MENU_SIZE,
	"BookLibraryUI": BOOK_LIBRARY_UI_SIZE,
	"BillPanel": BILL_PANEL_SIZE,
}


static func apply_main_scene_layout(parent_node: Node) -> void:
	apply_button_layout(parent_node)
	apply_right_panel_layout(parent_node)
	apply_craft_menu_layout(parent_node)


static func apply_button_layout(parent_node: Node) -> void:
	if parent_node == null:
		return
	for button_name in BUTTON_LAYOUTS.keys():
		var control := parent_node.get_node_or_null(String(button_name)) as Control
		if control == null:
			continue
		place_top_right_control(control, BUTTON_LAYOUTS[button_name], HudButtonStyle.HUD_BUTTON_SIZE)


static func apply_right_panel_layout(parent_node: Node) -> void:
	if parent_node == null:
		return
	for panel_name in RIGHT_PANEL_LAYOUTS.keys():
		var control := parent_node.get_node_or_null(String(panel_name)) as Control
		if control == null:
			continue
		place_bottom_right_control(control, RIGHT_PANEL_MARGIN, RIGHT_PANEL_LAYOUTS[panel_name])


static func apply_ai_character_hud_layout(control: Control) -> void:
	place_bottom_right_control(control, RIGHT_PANEL_MARGIN, AI_CHARACTER_HUD_SIZE)


static func apply_craft_menu_layout(parent_node: Node) -> void:
	if parent_node == null:
		return
	var control := parent_node.get_node_or_null("CraftMenu") as Control
	if control == null:
		return
	place_top_right_control(control, CRAFT_MENU_POSITION, CRAFT_MENU_SIZE)


static func place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2) -> void:
	HudButtonStyle.place_top_right_control(control, top_right_offset, control_size)


static func place_bottom_right_control(control: Control, bottom_right_margin: Vector2, control_size: Vector2) -> void:
	HudButtonStyle.place_bottom_right_control(control, bottom_right_margin, control_size)
