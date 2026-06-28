extends WorldEnvironment
class_name CanvasGlowEnvironmentModule

@export var glow_intensity: float = 1.0
@export var glow_strength: float = 1.25
@export var glow_hdr_threshold: float = 1.0
@export var glow_bloom: float = 0.08


func _ready() -> void:
	_setup_canvas_glow()


func _setup_canvas_glow() -> void:
	var canvas_environment := environment
	if canvas_environment == null:
		canvas_environment = Environment.new()
		environment = canvas_environment

	canvas_environment.background_mode = Environment.BG_CANVAS
	canvas_environment.glow_enabled = true
	canvas_environment.set("glow_intensity", glow_intensity)
	canvas_environment.set("glow_strength", glow_strength)
	canvas_environment.set("glow_hdr_threshold", glow_hdr_threshold)
	canvas_environment.set("glow_bloom", glow_bloom)
