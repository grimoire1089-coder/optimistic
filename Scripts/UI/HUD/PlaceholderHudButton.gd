extends Button
class_name PlaceholderHudButton


func _ready() -> void:
	HudButtonStyle.apply_square_button_visual(self)
	if text.is_empty():
		text = "Placeholder"
