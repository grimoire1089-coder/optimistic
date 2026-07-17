extends "res://Scripts/Scenes/Main/MainScene.gd"

const RightHudLayout := preload("res://Scripts/UI/HUD/Modules/RightHudLayoutModule.gd")
const AI_CHARACTER_SELECTION_CONTEXT_SCRIPT := preload("res://Scripts/Characters/Selection/AICharacterSelectionContextModule.gd")
const AI_CHARACTER_INVENTORY_SELECTION_SCRIPT := preload("res://Scripts/UI/Inventory/AICharacterInventorySelectionModule.gd")


func _ready() -> void:
	_ensure_ai_character_selection_context()
	super._ready()
	_disconnect_legacy_robin_selection()
	_ensure_inventory_selection_module()


func _connect_robin_selection() -> void:
	pass


func _ensure_ai_character_selection_context() -> Node:
	var existing_context := get_node_or_null("AICharacterSelectionContextModule")
	if existing_context != null:
		return existing_context
	var context := AI_CHARACTER_SELECTION_CONTEXT_SCRIPT.new() as Node
	if context == null:
		return null
	context.name = "AICharacterSelectionContextModule"
	add_child(context)
	return context


func _ensure_inventory_selection_module() -> Node:
	if canvas_layer == null:
		return null
	var inventory_ui := canvas_layer.get_node_or_null("InventoryUI")
	if inventory_ui == null:
		return null
	var existing_module := inventory_ui.get_node_or_null("AICharacterInventorySelectionModule")
	if existing_module != null:
		return existing_module
	var module := AI_CHARACTER_INVENTORY_SELECTION_SCRIPT.new() as Node
	if module == null:
		return null
	module.name = "AICharacterInventorySelectionModule"
	inventory_ui.add_child(module)
	return module


func _disconnect_legacy_robin_selection() -> void:
	if robin == null:
		return
	var callable := Callable(self, "_on_robin_selected")
	if robin.selected.is_connected(callable):
		robin.selected.disconnect(callable)


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
