extends RefCounted
class_name BuildUiRuntime

const PANEL_PATH := "res://Scenes/UI/Build/FurnitureBuildInventory.tscn"


static func setup(button: Button, room_ok: bool) -> BuildModeController:
	var root := button.get_tree().current_scene
	if root == null:
		return null

	var controller := root.get_node_or_null("BuildModeController") as BuildModeController
	if controller == null:
		controller = BuildModeController.new()
		controller.name = "BuildModeController"
		controller.room_map_path = NodePath("../RobinRoomMap")
		controller.fallback_room_is_buildable = room_ok
		root.add_child(controller)

	var overlay := root.get_node_or_null("BuildGridHighlightOverlay")
	if overlay == null:
		var new_overlay := BuildGridHighlightOverlay.new()
		new_overlay.name = "BuildGridHighlightOverlay"
		new_overlay.z_index = -20
		new_overlay.room_map_path = NodePath("../RobinRoomMap")
		new_overlay.build_mode_controller_path = NodePath("../BuildModeController")
		root.add_child(new_overlay)

	var canvas := button.get_parent()
	if canvas != null and canvas.get_node_or_null("FurnitureBuildInventory") == null:
		var panel_scene := load(PANEL_PATH) as PackedScene
		if panel_scene != null:
			canvas.add_child(panel_scene.instantiate())

	return controller
