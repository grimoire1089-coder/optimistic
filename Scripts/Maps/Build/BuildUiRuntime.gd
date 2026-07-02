extends RefCounted
class_name BuildUiRuntime

const PANEL_PATH := "res://Scenes/UI/Build/FurnitureBuildInventory.tscn"
const PLACEMENT_PREVIEW_SCRIPT_PATH := "res://Scripts/Maps/Build/BuildFurniturePlacementPreview.gd"
const FLOOR_PLACEMENT_MODULE_SCRIPT_PATH := "res://Scripts/Maps/Floor/FloorPlacementModule.gd"
const DEFAULT_FLOOR_TEXTURE_PATH := "res://Assets/Maps/Furniture/Floor/Floor_001.png"
const PANEL_TOP_RIGHT_OFFSET := Vector2(-344.0, -492.0)
const PANEL_SIZE := Vector2(320.0, 468.0)


static func setup(button: Button, room_ok: bool) -> BuildModeController:
	var root := button.get_tree().current_scene
	if root == null:
		return null

	var controller := _get_or_create_controller(root, room_ok)
	_ensure_grid_overlay(root)
	_ensure_placement_preview(root)
	_ensure_floor_placement_module(root)
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


static func _ensure_floor_placement_module(root: Node) -> void:
	var existing_module := root.get_node_or_null("FloorPlacementModule")
	if existing_module != null:
		if not existing_module.is_in_group(&"floor_placement_module"):
			existing_module.add_to_group(&"floor_placement_module")
		return

	var floor_module_script := load(FLOOR_PLACEMENT_MODULE_SCRIPT_PATH) as Script
	if floor_module_script == null:
		return

	var floor_module := floor_module_script.new() as Node
	if floor_module == null:
		return

	floor_module.name = "FloorPlacementModule"
	floor_module.add_to_group(&"floor_placement_module")
	floor_module.set("room_map_path", NodePath("../RobinRoomMap"))
	floor_module.set("floor_root_path", NodePath("../RobinRoomMap/FloorRoot"))
	floor_module.set("floor_texture_path", DEFAULT_FLOOR_TEXTURE_PATH)
	floor_module.set("floor_footprint", Vector2i(15, 15))
	root.add_child.call_deferred(floor_module)


static func _ensure_furniture_inventory(button: Button) -> void:
	var canvas := button.get_parent()
	if canvas == null:
		return
	var existing_panel := canvas.get_node_or_null("FurnitureBuildInventory") as Control
	if existing_panel != null:
		_place_panel_bottom_right(existing_panel)
		return

	var panel_scene := load(PANEL_PATH) as PackedScene
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate() as Control
	if panel == null:
		return
	_place_panel_bottom_right(panel)
	canvas.add_child.call_deferred(panel)


static func _place_panel_bottom_right(panel: Control) -> void:
	if panel == null:
		return
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = PANEL_TOP_RIGHT_OFFSET.x
	panel.offset_top = PANEL_TOP_RIGHT_OFFSET.y
	panel.offset_right = PANEL_TOP_RIGHT_OFFSET.x + PANEL_SIZE.x
	panel.offset_bottom = PANEL_TOP_RIGHT_OFFSET.y + PANEL_SIZE.y
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN