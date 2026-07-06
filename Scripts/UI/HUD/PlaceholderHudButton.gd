extends Button
class_name PlaceholderHudButton

const PLACEHOLDER_LABEL_CODE := 0x4EEE


func _ready() -> void:
	HudButtonStyle.apply_square_button_visual(self)
	if text.is_empty() and icon == null:
		text = String.chr(PLACEHOLDER_LABEL_CODE)
