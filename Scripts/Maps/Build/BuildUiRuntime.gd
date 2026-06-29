extends RefCounted
class_name BuildUiRuntime

const PANEL_PATH := "res://Scenes/UI/Build/FurnitureBuildInventory.tscn"
const PLACEMENT_PREVIEW_SCRIPT_PATH := "res://Scripts/Maps/Build/BuildFurniturePlacementPreview.gd"


static func setup(button: Button, room_ok: bool) -> BuildModeController:
	var root := button.get_tree().current_scene
	if root == null:
		return null

	var controller := _get_or_create_controller(root, room_ok)
	_ensure_grid_overlay(root)
	_ensure_placement_preview(root)
	_ensure_furniture_inventory(button)
	return controller


static func _get_or_create_controller(root: Node, room_ok: bool) -> BuildModeController:
	var controller := root.get_node_or_null("BuildModeController") as BuildModeController
	if controller != null:
		if not controller.is_in_group(&"build_mode_controller"):
			controller.add_to_group(&"build_mode_controller")
		return controller

	controller = BuildModeController.new()
	controller.name = "BuildModeController"
	controller.room_map_path = NodePath("../RobinRoomMap")
	controller.fallback_room_is_buildable = room_ok
	controller.add_to_group(&"build_mode_controller")
	root.add_child.call_deferred(controller)
	return controller


static func _ensure_grid_overlay(root: Node) -> void:
	if root.get_node_or_null("BuildGridHighlightOverlay") != null:
		return

	var overlay := BuildGridHighlightOverlay.new()
	overlay.name = "BuildGridHighlightOverlay"
	overlay.z_index = -20
	overlay.room_map_path = NodePath("../RobinRoomMap")
	overlay.build_mode_controller_path = NodePath("../BuildModeController")
	root.add_child.call_deferred(overlay)


static func _ensure_placement_preview(root: Node) -> void:
	if root.get_node_or_null("BuildFurniturePlacementPreview") != null:
		return

	var preview_script := load(PLACEMENT_PREVIEW_SCRIPT_PATH) as Script
	if preview_script == null:
		return

	var preview := preview_script.new() as Node2D
	if preview == null:
		return

	preview.name = "BuildFurniturePlacementPreview"
	preview.z_index = 30
	preview.set("room_map_path", NodePath("../RobinRoomMap"))
	preview.set("build_mode_controller_path", NodePath("../BuildModeController"))
	preview.set("furniture_placement_module_path", NodePath("../FurniturePlacementModule"))
	root.add_child.call_deferred(preview)


static func _ensure_furniture_inventory(button: Button) -> void:
	var canvas := button.get_parent()
	if canvas == null:
		return
	if canvas.get_node_or_null("FurnitureBuildInventory") != null:
		return

	var panel_scene := load(PANEL_PATH) as PackedScene
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate()
	canvas.add_child.call_deferred(panel)
