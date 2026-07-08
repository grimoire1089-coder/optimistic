@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/robin_item_creator/ItemCreatorDock.tscn"
const BOTTOM_PANEL_TITLE := "Robin Item Creator"

var _panel: Control


func _enter_tree() -> void:
	_add_bottom_panel()


func _exit_tree() -> void:
	_remove_bottom_panel()


func _add_bottom_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	if not ResourceLoader.exists(DOCK_SCENE_PATH):
		push_warning("Robin Item Creator panel scene was not found: %s" % DOCK_SCENE_PATH)
		return
	var scene := load(DOCK_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("Robin Item Creator panel scene could not be loaded: %s" % DOCK_SCENE_PATH)
		return
	_panel = scene.instantiate() as Control
	if _panel == null:
		push_warning("Robin Item Creator panel scene root must be Control.")
		return
	add_control_to_bottom_panel(_panel, BOTTOM_PANEL_TITLE)


func _remove_bottom_panel() -> void:
	if _panel == null:
		return
	if is_instance_valid(_panel):
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
	_panel = null
