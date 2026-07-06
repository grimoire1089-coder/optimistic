extends "res://Scripts/Scenes/Main/MainScene.gd"

const RightHudLayout := preload("res://Scripts/UI/HUD/Modules/RightHudLayoutModule.gd")


func _apply_reserved_bottom_hud_layout() -> void:
	if canvas_layer == null:
		return
	RightHudLayout.apply_main_scene_layout(canvas_layer)
	_configure_map_grid_toggle_button(canvas_layer.get_node_or_null(MAP_GRID_TOGGLE_BUTTON_NAME) as Button)


func _set_non_build_buttons_disabled(is_disabled: bool) -> void:
	super(is_disabled)
	_set_canvas_button_disabled("MoveButton", is_disabled)
	_set_canvas_button_disabled("EncyclopediaButton", is_disabled)
	_set_canvas_button_disabled("SettingsButton", is_disabled)


func _get_startup_debug_text() -> String:
	var robin_room_map := get_node_or_null("RobinRoomMap") as RoomMapGridModule
	if robin_room_map == null:
		return "Main Scene"
	return robin_room_map.map_display_name
