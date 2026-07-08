@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/robin_item_creator/ItemCreatorDock.tscn"

var _dock: Control


func _enter_tree() -> void:
	_add_dock()


func _exit_tree() -> void:
	_remove_dock()


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
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _remove_dock() -> void:
	if _dock == null:
		return
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null
