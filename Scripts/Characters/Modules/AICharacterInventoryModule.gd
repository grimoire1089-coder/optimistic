extends AICharacterInventoryBaseModule
class_name AICharacterInventoryModule

@export var unlock_food_encyclopedia_on_acquire: bool = false


func _notify_food_encyclopedia_if_needed(category_id: StringName, item_id: StringName, display_name: String) -> void:
	if not unlock_food_encyclopedia_on_acquire:
		return
	super._notify_food_encyclopedia_if_needed(category_id, item_id, display_name)
