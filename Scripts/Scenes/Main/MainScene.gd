extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin_room_map: RoomMapGridModule = $RobinRoomMap
@onready var furniture_placement_module: FurniturePlacementModule = $FurniturePlacementModule
@onready var robin: RobinWanderActor = $Robin
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud


func _ready() -> void:
	debug_label.text = _get_startup_debug_text()
	_connect_robin_selection()


func _connect_robin_selection() -> void:
	if robin == null:
		return
	var callable := Callable(self, "_on_robin_selected")
	if not robin.selected.is_connected(callable):
		robin.selected.connect(callable)


func _on_robin_selected(actor: RobinWanderActor) -> void:
	if ai_character_hud == null:
		return
	ai_character_hud.show_actor(actor)


func _get_startup_debug_text() -> String:
	if robin_room_map == null:
		return "Main Scene 起動完了"
	var grid_size := robin_room_map.get_grid_size()
	return "%s 起動完了 / Grid %d x %d" % [robin_room_map.map_display_name, grid_size.x, grid_size.y]
