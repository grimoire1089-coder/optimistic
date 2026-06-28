extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var robin: RobinWanderActor = $Robin
@onready var ai_character_hud: AICharacterHud = $CanvasLayer/AICharacterHud


func _ready() -> void:
	debug_label.text = "Main Scene 起動完了"
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
