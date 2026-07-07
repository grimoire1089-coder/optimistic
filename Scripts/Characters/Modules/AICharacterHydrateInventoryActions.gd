extends RefCounted
class_name AICharacterHydrateInventoryActions

const FoodAccess := preload("res://Scripts/Characters/Modules/AICharacterInventoryFoodAccess.gd")


static func has_food(inventory: Node, food_data: FoodItemData) -> bool:
	return FoodAccess.has_food_item(inventory, food_data)


static func add_food(inventory: Node, food_data: FoodItemData, amount: int = 1) -> bool:
	return FoodAccess.add_food_item(inventory, food_data, amount)


static func remove_food(inventory: Node, food_data: FoodItemData, amount: int = 1) -> bool:
	if food_data == null:
		return false
	return FoodAccess.remove_item(inventory, food_data.category_id, food_data.item_id, amount)
