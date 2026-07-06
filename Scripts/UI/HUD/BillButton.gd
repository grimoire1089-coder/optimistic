extends Button
class_name BillButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var bill_panel_path: NodePath = NodePath("../BillPanel")
@export var fallback_group_name: StringName = &"bill_ui"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	_apply_square_button_layout()
	if text.is_empty() and icon == null:
		text = "請求"
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var bill_panel := _find_bill_panel()
	if bill_panel == null:
		push_warning("Bill panel not found: %s" % bill_panel_path)
		return

	if bill_panel.has_method("toggle_bill_panel"):
		bill_panel.call("toggle_bill_panel")
		return
	if bill_panel.has_method("toggle"):
		bill_panel.call("toggle")
		return
	if bill_panel.has_method("open"):
		bill_panel.call("open")
		return
	if bill_panel is CanvasItem:
		var canvas_item := bill_panel as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_bill_panel() -> Node:
	var bill_panel := get_node_or_null(bill_panel_path)
	if bill_panel != null:
		return bill_panel
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


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_BILL_LEFT)
	)
	HudButtonStyle.apply_icon_button_layout(self)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
