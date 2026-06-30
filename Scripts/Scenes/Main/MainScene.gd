extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin_room_map: RoomMapGridModule = $RobinRoomMap
@onready var furniture_placement_module: FurniturePlacementModule = $FurniturePlacementModule
@onready var robin: RobinWanderActor = $Robin
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud
@onready var message_log: MessageLogPanel = $CanvasLayer/MessageLogPanel


func _ready() -> void:
	_push_debug_message("System", "MainScene _ready 開始")
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
