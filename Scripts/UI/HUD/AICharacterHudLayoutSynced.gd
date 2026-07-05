extends AICharacterHud
class_name AICharacterHudLayoutSynced

const RightHudLayout := preload("res://Scripts/UI/HUD/Modules/RightHudLayoutModule.gd")


func _apply_wide_layout() -> void:
	RightHudLayout.apply_ai_character_hud_layout(self)
	if needs_panel != null:
		needs_panel.bar_width = RightHudLayout.AI_CHARACTER_NEED_BAR_WIDTH
		needs_panel.refresh()
