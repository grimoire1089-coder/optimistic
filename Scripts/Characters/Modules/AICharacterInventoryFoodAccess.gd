extends RefCounted
class_name AICharacterInventoryFoodAccess


static func has_food_item(inventory: Node, food_data: FoodItemData) -> bool:
	if food_data == null:
		return false
	return get_item_amount(inventory, food_data.category_id, food_data.item_id) > 0


static func get_item_amount(inventory: Node, category_id: StringName, item_id: StringName) -> int:
	if inventory == null or not inventory.has_method("get_items"):
		return 0
	var entries_value: Variant = inventory.call("get_items", category_id)
	if not (entries_value is Array):
		return 0
	var entries: Array = entries_value
	var total := 0
	for entry in entries:
		if entry is Dictionary and entry.get("id", &"") == item_id:
			total += int(entry.get("amount", 0))
	return total


static func add_food_item(inventory: Node, food_data: FoodItemData, amount: int = 1) -> bool:
	if inventory == null or food_data == null or amount <= 0:
		return false
	if inventory.has_method("add_food_item"):
		return inventory.call("add_food_item", food_data, amount) == true
	if not inventory.has_method("add_item"):
		return false
	return inventory.call(
		"add_item",
		food_data.category_id,
		food_data.item_id,
		food_data.display_name,
		amount,
		food_data.get_icon_path(),
		food_data.stack_max,
		food_data.description,
		food_data.buy_price,
		food_data.sell_price,
		food_data.get_need_effect_path(),
		food_data.can_discard,
		food_data.can_transfer,
		food_data.nutrition_value,
		food_data.hydration_value,
		food_data.extra_need_values,
		food_data.get_need_values(true),
		"",
		food_data.display_name
	) == true


static func remove_item(inventory: Node, category_id: StringName, item_id: StringName, amount: int = 1) -> bool:
	if inventory == null or amount <= 0:
		return false
	if not inventory.has_method("remove_item"):
		return false
	return inventory.call("remove_item", category_id, item_id, amount) == true
