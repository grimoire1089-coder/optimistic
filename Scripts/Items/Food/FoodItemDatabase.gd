extends Resource
class_name FoodItemDatabase

@export var foods: Array[FoodItemData] = []


func find_by_id(item_id: StringName) -> FoodItemData:
	for food in foods:
		if food == null:
			continue
		if food.item_id == item_id:
			return food
	return null
