extends "res://Scripts/Scenes/Main/MainScene.gd"

const RightHudLayout := preload("res://Scripts/UI/HUD/Modules/RightHudLayoutModule.gd")


func _apply_reserved_bottom_hud_layout() -> void:
	if canvas_layer == null:
		return
	RightHudLayout.apply_main_scene_layout(canvas_layer)
	_configure_map_grid_toggle_button(canvas_layer.get_node_or_null(MAP_GRID_TOGGLE_BUTTON_NAME) as Button)
