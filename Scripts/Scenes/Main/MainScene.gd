extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin_room_map: RoomMapGridModule = $RobinRoomMap
@onready var furniture_placement_module: FurniturePlacementModule = $FurniturePlacementModule
@onready var robin: RobinWanderActor = $Robin
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud
@onready var message_log: MessageLogPanel = $CanvasLayer/MessageLogPanel


func _ready() -> void:
	_push_debug_message("System", "MainScene _ready 開始")
	_ensure_infrastructure_room_runtime()
	var startup_debug_text := _get_startup_debug_text()
	debug_label.text = startup_debug_text
	_connect_robin_selection()
	_push_startup_message(startup_debug_text)
	_push_debug_result("System", "MainScene 初期化", true, startup_debug_text)


func _connect_robin_selection() -> void:
	if robin == null:
		_push_debug_result("System", "Robin selected signal 接続", false, "Robin が見つかりません")
		return
	var callable := Callable(self, "_on_robin_selected")
	if not robin.selected.is_connected(callable):
		robin.selected.connect(callable)
		_push_debug_result("System", "Robin selected signal 接続", true, "接続しました")
		return
	_push_debug_result("System", "Robin selected signal 接続", true, "すでに接続済み")


func _on_robin_selected(actor: RobinWanderActor) -> void:
	var actor_name := "AI Character"
	if actor != null:
		actor_name = actor.display_name
	_push_debug_message("AI:%s" % actor_name, "選択されました。HUD表示を試行します")

	if ai_character_hud == null:
		_push_debug_result("AI HUD", "show_actor", false, "AICharacterHud が見つかりません")
		return
	ai_character_hud.show_actor(actor)
	_push_debug_result("AI HUD", "show_actor", true, "target=%s" % actor_name)


func _ensure_infrastructure_room_runtime() -> void:
	_ensure_infrastructure_room_map()
	_ensure_map_travel_buttons()
	_ensure_map_travel_module()


func _ensure_infrastructure_room_map() -> void:
	if get_node_or_null("InfrastructureRoomMap") != null:
		return
	if robin_room_map == null:
		return

	var infrastructure_room_map := RoomMapGridModule.new()
	infrastructure_room_map.name = "InfrastructureRoomMap"
	infrastructure_room_map.visible = false
	infrastructure_room_map.z_index = robin_room_map.z_index
	infrastructure_room_map.map_id = &"infrastructure_room"
	infrastructure_room_map.map_display_name = "インフラルーム"
	infrastructure_room_map.buildable = false
	infrastructure_room_map.screen_margin = robin_room_map.screen_margin
	infrastructure_room_map.side_ui_margin = robin_room_map.side_ui_margin
	infrastructure_room_map.cell_size = robin_room_map.cell_size
	infrastructure_room_map.fixed_grid_size = robin_room_map.fixed_grid_size
	infrastructure_room_map.fit_cell_size_to_visual_rect = robin_room_map.fit_cell_size_to_visual_rect
	infrastructure_room_map.show_grid = robin_room_map.show_grid
	infrastructure_room_map.show_neon_frame = robin_room_map.show_neon_frame
	infrastructure_room_map.grid_line_width = robin_room_map.grid_line_width
	infrastructure_room_map.grid_line_color = robin_room_map.grid_line_color
	infrastructure_room_map.grid_border_width = robin_room_map.grid_border_width
	infrastructure_room_map.grid_border_color = robin_room_map.grid_border_color
	infrastructure_room_map.frame_outer_glow_width = robin_room_map.frame_outer_glow_width
	infrastructure_room_map.frame_middle_glow_width = robin_room_map.frame_middle_glow_width
	infrastructure_room_map.frame_core_line_width = robin_room_map.frame_core_line_width
	add_child(infrastructure_room_map)
	move_child(infrastructure_room_map, robin_room_map.get_index() + 1)

	var furniture_root := Node2D.new()
	furniture_root.name = "FurnitureRoot"
	furniture_root.z_index = 1
	infrastructure_room_map.add_child(furniture_root)


func _ensure_map_travel_buttons() -> void:
	if canvas_layer == null:
		return
	_ensure_map_travel_button("ToInfrastructureRoomButton", "インフラへ", "インフラルームへ移動", true)
	_ensure_map_travel_button("ToRobinRoomButton", "部屋へ戻る", "ロビンの部屋へ戻る", false)


func _ensure_map_travel_button(button_name: String, text_value: String, tooltip_value: String, visible_on_start: bool) -> Button:
	var existing_button := canvas_layer.get_node_or_null(button_name) as Button
	if existing_button != null:
		return existing_button

	var button := Button.new()
	button.name = button_name
	button.offset_left = 24.0
	button.offset_top = 64.0
	button.offset_right = 176.0
	button.offset_bottom = 104.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = text_value
	button.tooltip_text = tooltip_value
	button.visible = visible_on_start
	canvas_layer.add_child(button)
	return button


func _ensure_map_travel_module() -> void:
	if get_node_or_null("MainSceneMapTravelModule") != null:
		return
	var map_travel_module := MainSceneMapTravelModule.new()
	map_travel_module.name = "MainSceneMapTravelModule"
	add_child(map_travel_module)


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
	if robin_room_map == null:
		return "Main Scene 起動完了"
	var grid_size := robin_room_map.get_grid_size()
	return "%s 起動完了 / Grid %d x %d" % [robin_room_map.map_display_name, grid_size.x, grid_size.y]
