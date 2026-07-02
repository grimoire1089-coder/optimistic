extends Node2D

const MAP_RUNTIME_MODULE_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneMapRuntimeModule.tscn"
const MAP_TRAVEL_MODULE_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneMapTravelModule.tscn"
const MAP_ENTRANCE_MODULE_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneMapEntranceModule.tscn"
const TRAVEL_BUTTONS_ROOT_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneTravelButtonsRoot.tscn"
const LOCATION_BACKGROUND_SCRIPT_PATH := "res://Scripts/Maps/Location/LocationBackgroundNode.gd"
const DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH := "res://Assets/Maps/Location/Location_001.png"
const ENTRANCE_TRAVEL_SFX_PATH := "res://Assets/Audio/SFX/Game/Sci-fi_door_opening.ogg"
const RIGHT_TRAVEL_BUTTON_POSITION := Vector2(-332.0, 184.0)
const RIGHT_TRAVEL_BUTTON_SIZE := Vector2(48.0, 48.0)
const MAP_GRID_TOGGLE_BUTTON_NAME := "MapGridToggleButton"
const MAP_GRID_TOGGLE_BUTTON_POSITION := Vector2(-328.0, 108.0)
const MAP_GRID_TOGGLE_BUTTON_SIZE := Vector2(48.0, 48.0)

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin: RobinWanderActor = $Robin
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud
@onready var message_log: MessageLogPanel = $CanvasLayer/MessageLogPanel

var _last_build_mode_enabled: bool = false


func _ready() -> void:
	_push_debug_message("System", "MainScene _ready start")
	_ensure_runtime_children()
	_ensure_map_grid_toggle_button()
	_apply_reserved_bottom_hud_layout()
	var startup_debug_text := _get_startup_debug_text()
	debug_label.text = startup_debug_text
	_connect_robin_selection()
	_push_startup_message(startup_debug_text)
	_push_debug_result("System", "MainScene init", true, startup_debug_text)
	_sync_build_mode_ui_lock()


func _process(_delta: float) -> void:
	_sync_build_mode_ui_lock()


func _connect_robin_selection() -> void:
	if robin == null:
		_push_debug_result("System", "Robin selected signal connect", false, "Robin not found")
		return
	var callable := Callable(self, "_on_robin_selected")
	if not robin.selected.is_connected(callable):
		robin.selected.connect(callable)
		_push_debug_result("System", "Robin selected signal connect", true, "connected")
		return
	_push_debug_result("System", "Robin selected signal connect", true, "already connected")


func _on_robin_selected(actor: RobinWanderActor) -> void:
	var actor_name := "AI Character"
	if actor != null:
		actor_name = actor.display_name
	_push_debug_message("AI:%s" % actor_name, "selected. Try toggling HUD")

	if _is_build_mode_enabled():
		_push_debug_result("AI HUD", "toggle_actor", false, "Build mode is enabled")
		return

	if ai_character_hud == null:
		_push_debug_result("AI HUD", "toggle_actor", false, "AICharacterHud not found")
		return
	ai_character_hud.toggle_actor(actor)
	_push_debug_result("AI HUD", "toggle_actor", true, "target=%s" % actor_name)


func _ensure_runtime_children() -> void:
	var map_runtime_module := _ensure_main_child_from_scene("MainSceneMapRuntimeModule", MAP_RUNTIME_MODULE_SCENE_PATH)
	if map_runtime_module != null and map_runtime_module.has_method("ensure_runtime_maps"):
		map_runtime_module.call("ensure_runtime_maps")

	_ensure_location_background()

	var map_travel_module := _ensure_main_child_from_scene("MainSceneMapTravelModule", MAP_TRAVEL_MODULE_SCENE_PATH)
	if map_travel_module != null:
		map_travel_module.set("use_travel_buttons", false)
		map_travel_module.set("travel_sfx_path", ENTRANCE_TRAVEL_SFX_PATH)

	var map_entrance_module := _ensure_main_child_from_scene("MainSceneMapEntranceModule", MAP_ENTRANCE_MODULE_SCENE_PATH)
	if map_entrance_module != null and map_entrance_module.has_method("ensure_runtime_entrances"):
		map_entrance_module.call("ensure_runtime_entrances")


func _ensure_main_child_from_scene(node_name: String, scene_path: String) -> Node:
	var existing_node := get_node_or_null(node_name)
	if existing_node != null:
		return existing_node

	var node := _instantiate_scene(scene_path)
	if node == null:
		node = Node.new()
	node.name = node_name
	add_child(node)
	return node


func _ensure_location_background() -> Node2D:
	var existing_background := get_node_or_null("LocationBackground") as Node2D
	if existing_background != null:
		return existing_background

	var location_background_script := load(LOCATION_BACKGROUND_SCRIPT_PATH) as Script
	if location_background_script == null:
		return null

	var background := location_background_script.new() as Node2D
	if background == null:
		return null
	background.name = "LocationBackground"
	background.z_index = -40
	background.set("room_map_path", NodePath("../RobinRoomMap"))
	background.set("texture_path", DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH)
	add_child(background)
	return background


func _ensure_travel_buttons_root() -> Control:
	if canvas_layer == null:
		return null

	var existing_root := canvas_layer.get_node_or_null("MainSceneTravelButtons") as Control
	if existing_root != null:
		_configure_travel_buttons_root(existing_root)
		return existing_root

	var root := _instantiate_scene(TRAVEL_BUTTONS_ROOT_SCENE_PATH) as Control
	if root == null:
		root = Control.new()
	root.name = "MainSceneTravelButtons"
	_configure_travel_buttons_root(root)
	canvas_layer.add_child(root)
	return root


func _configure_travel_buttons_root(root: Control) -> void:
	if root == null:
		return
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _instantiate_scene(scene_path: String) -> Node:
	if scene_path.is_empty():
		return null
	if not ResourceLoader.exists(scene_path):
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate()


func _ensure_map_travel_button(parent: Control, button_name: String, text_value: String, tooltip_value: String, visible_on_start: bool) -> Button:
	if parent == null:
		return null
	var existing_button := parent.get_node_or_null(button_name) as Button
	if existing_button != null:
		_configure_right_travel_button(existing_button, text_value, tooltip_value, visible_on_start)
		return existing_button

	var button := Button.new()
	button.name = button_name
	_configure_right_travel_button(button, text_value, tooltip_value, visible_on_start)
	parent.add_child(button)
	return button


func _configure_right_travel_button(button: Button, text_value: String, tooltip_value: String, visible_on_start: bool) -> void:
	button.custom_minimum_size = RIGHT_TRAVEL_BUTTON_SIZE
	button.anchor_left = 1.0
	button.anchor_top = 0.0
	button.anchor_right = 1.0
	button.anchor_bottom = 0.0
	button.offset_left = RIGHT_TRAVEL_BUTTON_POSITION.x
	button.offset_top = RIGHT_TRAVEL_BUTTON_POSITION.y
	button.offset_right = RIGHT_TRAVEL_BUTTON_POSITION.x + RIGHT_TRAVEL_BUTTON_SIZE.x
	button.offset_bottom = RIGHT_TRAVEL_BUTTON_POSITION.y + RIGHT_TRAVEL_BUTTON_SIZE.y
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = text_value
	button.tooltip_text = tooltip_value
	button.visible = visible_on_start


func _ensure_map_grid_toggle_button() -> Button:
	if canvas_layer == null:
		return null
	var button := canvas_layer.get_node_or_null(MAP_GRID_TOGGLE_BUTTON_NAME) as Button
	if button == null:
		button = Button.new()
		button.name = MAP_GRID_TOGGLE_BUTTON_NAME
		canvas_layer.add_child(button)
	_configure_map_grid_toggle_button(button)
	return button


func _configure_map_grid_toggle_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = MAP_GRID_TOGGLE_BUTTON_SIZE
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_place_top_right_control(button, MAP_GRID_TOGGLE_BUTTON_POSITION, MAP_GRID_TOGGLE_BUTTON_SIZE)
	if not button.pressed.is_connected(_on_map_grid_toggle_button_pressed):
		button.pressed.connect(_on_map_grid_toggle_button_pressed)
	_refresh_map_grid_toggle_button()


func _on_map_grid_toggle_button_pressed() -> void:
	var room_map := get_node_or_null("RobinRoomMap") as RoomMapGridModule
	var button := _ensure_map_grid_toggle_button()
	if room_map == null or button == null:
		return
	room_map.show_grid = button.button_pressed
	room_map.queue_redraw()
	_refresh_map_grid_toggle_button()


func _refresh_map_grid_toggle_button() -> void:
	if canvas_layer == null:
		return
	var button := canvas_layer.get_node_or_null(MAP_GRID_TOGGLE_BUTTON_NAME) as Button
	if button == null:
		return
	var room_map := get_node_or_null("RobinRoomMap") as RoomMapGridModule
	var is_grid_visible := room_map == null or room_map.show_grid
	button.set_pressed_no_signal(is_grid_visible)
	button.text = "GRID" if is_grid_visible else "OFF"
	button.tooltip_text = "薄いグリッドを非表示" if is_grid_visible else "薄いグリッドを表示"
	_apply_map_grid_toggle_button_style(button, is_grid_visible)


func _apply_map_grid_toggle_button_style(button: Button, is_grid_visible: bool) -> void:
	var bg_color := Color(0.01, 0.025, 0.04, 0.88) if is_grid_visible else Color(0.035, 0.035, 0.045, 0.92)
	var border_color := Color(0.33, 0.85, 1.0, 0.95) if is_grid_visible else Color(0.25, 0.32, 0.38, 0.95)
	var font_color := Color(0.33, 0.85, 1.0, 1.0) if is_grid_visible else Color(0.62, 0.70, 0.76, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	style.set_content_margin_all(0.0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_font_size_override("font_size", 10)


func _apply_reserved_bottom_hud_layout() -> void:
	if canvas_layer == null:
		return

	_place_top_right_control(canvas_layer.get_node_or_null("RobinHudButton") as Control, Vector2(-332.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("CraftButton") as Control, Vector2(-280.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("ShopButton") as Control, Vector2(-228.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("InventoryButton") as Control, Vector2(-176.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("BuildModeButton") as Control, Vector2(-124.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("WorkCreditButton") as Control, Vector2(-72.0, 184.0), RIGHT_TRAVEL_BUTTON_SIZE)
	_place_top_right_control(canvas_layer.get_node_or_null("AICharacterHud") as Control, Vector2(-328.0, 400.0), Vector2(304.0, 288.0))
	_place_top_right_control(canvas_layer.get_node_or_null("WorkMenu") as Control, Vector2(-328.0, 252.0), Vector2(304.0, 158.0))
	_place_top_right_control(canvas_layer.get_node_or_null("CraftMenu") as Control, Vector2(-328.0, 252.0), Vector2(304.0, 172.0))
	_configure_map_grid_toggle_button(canvas_layer.get_node_or_null(MAP_GRID_TOGGLE_BUTTON_NAME) as Button)


func _place_top_right_control(control: Control, top_right_offset: Vector2, control_size: Vector2) -> void:
	if control == null:
		return
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = top_right_offset.x
	control.offset_top = top_right_offset.y
	control.offset_right = top_right_offset.x + control_size.x
	control.offset_bottom = top_right_offset.y + control_size.y


func _sync_build_mode_ui_lock() -> void:
	var build_mode_enabled := _is_build_mode_enabled()
	if build_mode_enabled and not _last_build_mode_enabled:
		_close_non_build_modal_ui()
	_set_non_build_buttons_disabled(build_mode_enabled)
	_last_build_mode_enabled = build_mode_enabled


func _is_build_mode_enabled() -> bool:
	var controller := get_node_or_null("BuildModeController") as BuildModeController
	if controller == null:
		controller = get_tree().get_first_node_in_group(&"build_mode_controller") as BuildModeController
	if controller == null:
		return false
	return controller.is_build_mode_enabled()


func _close_non_build_modal_ui() -> void:
	_close_canvas_child("AICharacterHud", &"hide_hud")
	_close_canvas_child("ShopMenu", &"close_menu")
	_close_canvas_child("CraftMenu", &"close_menu")
	_close_canvas_child("InventoryUI", &"close")
	_close_canvas_child("WorkMenu", &"close_menu")


func _close_canvas_child(node_name: String, close_method: StringName) -> void:
	if canvas_layer == null:
		return
	var node := canvas_layer.get_node_or_null(node_name)
	if node == null:
		return
	if node.has_method(close_method):
		node.call(close_method)
		return
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		canvas_item.visible = false


func _set_non_build_buttons_disabled(is_disabled: bool) -> void:
	if canvas_layer == null:
		return
	_set_canvas_button_disabled("RobinHudButton", is_disabled)
	_set_canvas_button_disabled("CraftButton", is_disabled)
	_set_canvas_button_disabled("ShopButton", is_disabled)
	_set_canvas_button_disabled("InventoryButton", is_disabled)
	_set_canvas_button_disabled("WorkCreditButton", is_disabled)
	_set_canvas_button_disabled("ToInfrastructureRoomButton", is_disabled)
	_set_canvas_button_disabled("ToRobinRoomButton", is_disabled)


func _set_canvas_button_disabled(node_name: String, is_disabled: bool) -> void:
	if canvas_layer == null:
		return
	var direct_button := canvas_layer.get_node_or_null(node_name) as BaseButton
	if direct_button != null:
		direct_button.disabled = is_disabled
		return
	var travel_root := canvas_layer.get_node_or_null("MainSceneTravelButtons")
	if travel_root == null:
		return
	var travel_button := travel_root.get_node_or_null(node_name) as BaseButton
	if travel_button == null:
		return
	travel_button.disabled = is_disabled


func _push_startup_message(message: String) -> void:
	if message_log == null:
		return
	message_log.add_message(message)


func _push_debug_message(source: String, message: String) -> void:
	if message_log == null:
		return
	message_log.add_debug_message("[%s] %s" % [source, message])


func _push_debug_result(source: String, action: String, success: bool, detail: String = "") -> void:
	if message_log == null:
		return
	message_log.add_debug_result(source, action, success, detail)


func _get_startup_debug_text() -> String:
	var robin_room_map := get_node_or_null("RobinRoomMap") as RoomMapGridModule
	if robin_room_map == null:
		return "Main Scene"
	var grid_size := robin_room_map.get_grid_size()
	return "%s / Grid %d x %d" % [robin_room_map.map_display_name, grid_size.x, grid_size.y]
