extends Button
class_name InventoryButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const INVENTORY_BUTTON_GROUP: StringName = &"inventory_button"

@export var inventory_ui_path: NodePath = NodePath("../InventoryUI")
@export var fallback_group_name: StringName = &"inventory_ui"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	if not is_in_group(INVENTORY_BUTTON_GROUP):
		add_to_group(INVENTORY_BUTTON_GROUP)
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
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_INVENTORY_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
