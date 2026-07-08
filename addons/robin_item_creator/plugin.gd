@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/robin_item_creator/ItemCreatorDock.tscn"
const TOOL_MENU_ITEM_NAME := "Robin Item Creatorを開く"

var _dock: Control


func _enter_tree() -> void:
	add_tool_menu_item(TOOL_MENU_ITEM_NAME, Callable(self, "_on_open_item_creator_requested"))


func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_MENU_ITEM_NAME)
	_remove_dock()


func _on_open_item_creator_requested() -> void:
	_add_dock()
	if _dock != null and is_instance_valid(_dock):
		_dock.visible = true
	_focus_dock_if_possible()


func _add_dock() -> void:
	if _dock != null and is_instance_valid(_dock):
		return
	if not ResourceLoader.exists(DOCK_SCENE_PATH):
		push_warning("Robin Item Creator dock scene was not found: %s" % DOCK_SCENE_PATH)
		return
	var scene := load(DOCK_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("Robin Item Creator dock scene could not be loaded: %s" % DOCK_SCENE_PATH)
		return
	_dock = scene.instantiate() as Control
	if _dock == null:
		push_warning("Robin Item Creator dock scene root must be Control.")
		return
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)


func _focus_dock_if_possible() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	var focus_target := _dock.find_child("CloseButton", true, false) as Control
	if focus_target != null:
		focus_target.grab_focus()
		return
	_dock.grab_focus()


func _remove_dock() -> void:
	if _dock == null:
		return
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null
