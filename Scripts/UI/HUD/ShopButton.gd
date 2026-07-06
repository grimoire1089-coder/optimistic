extends Button
class_name ShopButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_SHOP_ICON_PATH := "res://Assets/UI/Icons/Shop.png"

@export var label_text: String = "ショップ"
@export var shop_menu_path: NodePath = NodePath("../ShopMenu")
@export var fallback_group_name: StringName = &"shop_menu"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var shop_icon: Texture2D


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_shop_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	elif text.is_empty():
		text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var shop_menu := _find_shop_menu()
	if shop_menu == null:
		push_warning("Shop menu not found: %s" % shop_menu_path)
		return

	if shop_menu.has_method("toggle_menu"):
		shop_menu.call("toggle_menu")
		return
	if shop_menu.has_method("open_menu"):
		shop_menu.call("open_menu")
		return
	if shop_menu is CanvasItem:
		var canvas_item := shop_menu as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_shop_menu() -> Node:
	var shop_menu := get_node_or_null(shop_menu_path)
	if shop_menu != null:
		return shop_menu
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


func _load_default_shop_icon_if_needed() -> void:
	if shop_icon == null and icon != null:
		shop_icon = icon
	if shop_icon == null and ResourceLoader.exists(DEFAULT_SHOP_ICON_PATH):
		shop_icon = load(DEFAULT_SHOP_ICON_PATH) as Texture2D
	if shop_icon != null:
		icon = shop_icon


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_SHOP_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
