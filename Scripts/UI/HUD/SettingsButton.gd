extends Button
class_name SettingsButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "設定"
@export var options_overlay_path: NodePath = NodePath("../GameOptionsOverlay")
@export var fallback_group_name: StringName = &"game_options_overlay"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	add_to_group("settings_button")
	_apply_square_button_layout()
	text = label_text
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var options_overlay: Node = _find_options_overlay()
	if options_overlay == null:
		push_warning("Game options overlay not found: %s" % options_overlay_path)
		return

	if options_overlay.has_method("open_options"):
		options_overlay.call("open_options")
		return
	if options_overlay.has_method("toggle_options"):
		options_overlay.call("toggle_options")
		return
	if options_overlay is CanvasItem:
		var canvas_item: CanvasItem = options_overlay as CanvasItem
		canvas_item.visible = true


func _find_options_overlay() -> Node:
	var options_overlay: Node = get_node_or_null(options_overlay_path)
	if options_overlay != null:
		return options_overlay
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
		HudButtonStyle.second_row_offset(HudButtonStyle.SECOND_ROW_SETTINGS_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
