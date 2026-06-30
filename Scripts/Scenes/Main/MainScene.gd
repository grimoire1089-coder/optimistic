extends Node2D

const MAP_RUNTIME_MODULE_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneMapRuntimeModule.tscn"
const MAP_TRAVEL_MODULE_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneMapTravelModule.tscn"
const TRAVEL_BUTTONS_ROOT_SCENE_PATH := "res://Scenes/Main/Modules/MainSceneTravelButtonsRoot.tscn"

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin: RobinWanderActor = $Robin
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud
@onready var message_log: MessageLogPanel = $CanvasLayer/MessageLogPanel


func _ready() -> void:
	_push_debug_message("System", "MainScene _ready 開始")
	_ensure_runtime_children()
	_apply_reserved_bottom_hud_layout()
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
	_push_debug_message("AI:%s" % actor_name, "選択されました。HUD切り替えを試行します")

	if ai_character_hud == null:
		_push_debug_result("AI HUD", "toggle_actor", false, "AICharacterHud が見つかりません")
		return
	ai_character_hud.toggle_actor(actor)
	_push_debug_result("AI HUD", "toggle_actor", true, "target=%s" % actor_name)


func _ensure_runtime_children() -> void:
	var map_runtime_module := _ensure_main_child_from_scene("MainSceneMapRuntimeModule", MAP_RUNTIME_MODULE_SCENE_PATH)
	if map_runtime_module != null and map_runtime_module.has_method("ensure_runtime_maps"):
		map_runtime_module.call("ensure_runtime_maps")

	var travel_buttons_root := _ensure_travel_buttons_root()
	_ensure_map_travel_button(travel_buttons_root, "ToInfrastructureRoomButton", "インフラへ", "インフラルームへ移動", true)
	_ensure_map_travel_button(travel_buttons_root, "ToRobinRoomButton", "部屋へ戻る", "ロビンの部屋へ戻る", false)

	var map_travel_module := _ensure_main_child_from_scene("MainSceneMapTravelModule", MAP_TRAVEL_MODULE_SCENE_PATH)
	if map_travel_module != null:
		map_travel_module.set("to_infrastructure_button_path", NodePath("../CanvasLayer/MainSceneTravelButtons/ToInfrastructureRoomButton"))
		map_travel_module.set("to_robin_room_button_path", NodePath("../CanvasLayer/MainSceneTravelButtons/ToRobinRoomButton"))


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


func _ensure_travel_buttons_root() -> Control:
	if canvas_layer == null:
		return null

	var existing_root := canvas_layer.get_node_or_null("MainSceneTravelButtons") as Control
	if existing_root != null:
		return existing_root

	var root := _instantiate_scene(TRAVEL_BUTTONS_ROOT_SCENE_PATH) as Control
	if root == null:
		root = Control.new()
	root.name = "MainSceneTravelButtons"
	canvas_layer.add_child(root)
	return root


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
	parent.add_child(button)
	return button


func _apply_reserved_bottom_hud_layout() -> void:
	if canvas_layer == null:
		return

	_place_top_right_control(canvas_layer.get_node_or_null("ShopButton") as Control, Vector2(-304.0, 176.0), Vector2(64.0, 64.0))
	_place_top_right_control(canvas_layer.get_node_or_null("InventoryButton") as Control, Vector2(-232.0, 176.0), Vector2(64.0, 64.0))
	_place_top_right_control(canvas_layer.get_node_or_null("BuildModeButton") as Control, Vector2(-160.0, 176.0), Vector2(64.0, 64.0))
	_place_top_right_control(canvas_layer.get_node_or_null("WorkCreditButton") as Control, Vector2(-88.0, 176.0), Vector2(64.0, 64.0))
	_place_top_right_control(canvas_layer.get_node_or_null("AICharacterHud") as Control, Vector2(-368.0, 260.0), Vector2(344.0, 300.0))
	_place_top_right_control(canvas_layer.get_node_or_null("WorkMenu") as Control, Vector2(-360.0, 260.0), Vector2(336.0, 158.0))


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
		return "Main Scene 起動完了"
	var grid_size := robin_room_map.get_grid_size()
	return "%s 起動完了 / Grid %d x %d" % [robin_room_map.map_display_name, grid_size.x, grid_size.y]
