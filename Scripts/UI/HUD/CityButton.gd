extends Button
class_name CityButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_CITY_ICON_PATH := "res://Assets/UI/Icons/Decadence.png"

@export var city_panel_path: NodePath = NodePath("../CityPanel")
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var city_icon: Texture2D


func _ready() -> void:
	HudButtonStyle.apply_square_button_visual(self)
	_load_default_city_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var city_panel := get_node_or_null(city_panel_path)
	if city_panel == null:
		return
	if city_panel.has_method("toggle_menu"):
		city_panel.call("toggle_menu")
		return
	if city_panel.has_method("open_menu"):
		city_panel.call("open_menu")
		return
	if city_panel is CanvasItem:
		var canvas_item := city_panel as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_city_icon_if_needed() -> void:
	if city_icon == null and icon != null:
		city_icon = icon
	if city_icon == null and ResourceLoader.exists(DEFAULT_CITY_ICON_PATH):
		city_icon = load(DEFAULT_CITY_ICON_PATH) as Texture2D
	if city_icon != null:
		icon = city_icon
