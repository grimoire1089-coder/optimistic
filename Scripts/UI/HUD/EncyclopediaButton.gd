extends Button
class_name EncyclopediaButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "図鑑"
@export var encyclopedia_overlay_path: NodePath = NodePath("../EncyclopediaOverlay")
@export var fallback_group_name: StringName = &"encyclopedia_overlay"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0


func _ready() -> void:
	add_to_group("encyclopedia_button")
	HudButtonStyle.apply_square_button_visual(self)
	HudButtonStyle.apply_icon_button_layout(self)
	text = label_text
	_load_default_click_sfx_if_needed()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var encyclopedia_overlay: Node = _find_encyclopedia_overlay()
	if encyclopedia_overlay == null:
		push_warning("Encyclopedia overlay not found: %s" % encyclopedia_overlay_path)
		return

	if encyclopedia_overlay.has_method("open_encyclopedia"):
		encyclopedia_overlay.call("open_encyclopedia")
		return
	if encyclopedia_overlay.has_method("toggle_encyclopedia"):
		encyclopedia_overlay.call("toggle_encyclopedia")
		return
	if encyclopedia_overlay is CanvasItem:
		var canvas_item := encyclopedia_overlay as CanvasItem
		canvas_item.visible = true


func _find_encyclopedia_overlay() -> Node:
	var encyclopedia_overlay := get_node_or_null(encyclopedia_overlay_path)
	if encyclopedia_overlay != null:
		return encyclopedia_overlay
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
