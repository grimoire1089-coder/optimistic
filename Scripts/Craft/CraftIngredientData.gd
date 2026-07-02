extends Resource
class_name CraftIngredientData

@export var item_data: FoodItemData
@export_range(1, 999, 1) var amount: int = 1


func get_item_id() -> StringName:
	if item_data == null:
		return &""
	return item_data.item_id


func get_category_id() -> StringName:
	if item_data == null:
		return &""
	return item_data.category_id


func get_display_name() -> String:
	if item_data == null:
		return ""
	return item_data.display_name
