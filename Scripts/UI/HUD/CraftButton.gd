extends Button
class_name CraftButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "Craft"
@export var craft_menu_path: NodePath = NodePath("../CraftMenu")
@export var fallback_group_name: StringName = &"craft_menu"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0

func _ready() -> void:
	text = label_text
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var craft_menu := _find_craft_menu()
	if craft_menu == null:
		return
	if craft_menu.has_method("toggle_menu"):
		craft_menu.call("toggle_menu")
		return

func _find_craft_menu() -> Node:
	var craft_menu := get_node_or_null(craft_menu_path)
	if craft_menu != null:
		return craft_menu
	return get_tree().get_first_node_in_group(fallback_group_name)
