extends Node2D

@onready var debug_label: Label = $CanvasLayer/DebugLabel


func _ready() -> void:
	debug_label.text = "Main Scene 起動完了"
