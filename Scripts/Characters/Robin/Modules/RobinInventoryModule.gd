extends Node
class_name RobinInventoryModule

signal inventory_changed

const CATEGORY_TOOLS := &"tools"
const CATEGORY_FOODS := &"foods"
const CATEGORY_DRINKS := &"drinks"
const CATEGORY_RECIPES := &"recipes"
const CATEGORY_MATERIALS := &"materials"
const CATEGORY_INGREDIENTS := &"ingredients"

@export var slots_per_category: int = 25

var _categories: Array[Dictionary] = [
	{"id": CATEGORY_TOOLS, "display_name": "ツール"},
	{"id": CATEGORY_FOODS, "display_name": "食品"},
	{"id": CATEGORY_DRINKS, "display_name": "飲料"},
	{"id": CATEGORY_RECIPES, "display_name": "レシピ"},
	{"id": CATEGORY_MATERIALS, "display_name": "素材"},
	{"id": CATEGORY_INGREDIENTS, "display_name": "食材"},
]

var _items_by_category: Dictionary = {}


func _ready() -> void:
	_setup_empty_categories()


func get_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in _categories:
		result.append((category as Dictionary).duplicate(true))
	return result


func get_slots_per_category() -> int:
	return max(slots_per_category, 0)


func get_items(category_id: StringName) -> Array[Dictionary]:
	_setup_empty_categories()
	var result: Array[Dictionary] = []
	if not _items_by_category.has(category_id):
		return result

	var items := _items_by_category[category_id] as Array
	for item in items:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func add_item(category_id: StringName, item_id: StringName, display_name: String, amount: int = 1, icon_path: String = "") -> bool:
	if amount <= 0:
		return false
	if not has_category(category_id):
		push_warning("存在しないインベントリカテゴリです: %s" % category_id)
		return false

	_setup_empty_categories()
	var items := _items_by_category[category_id] as Array
	for item in items:
		if item.get("id", &"") == item_id:
			item["amount"] = int(item.get("amount", 0)) + amount
			inventory_changed.emit()
			return true

	if items.size() >= get_slots_per_category():
		push_warning("インベントリがいっぱいです: %s" % category_id)
		return false

	items.append({
		"id": item_id,
		"category_id": category_id,
		"display_name": display_name,
		"amount": amount,
		"icon_path": icon_path,
	})
	inventory_changed.emit()
	return true


func add_food_item(food_data: FoodItemData, amount: int = 1) -> bool:
	if food_data == null:
		push_warning("食品データが空です。")
		return false
	if food_data.item_id == &"":
		push_warning("食品IDが空です。")
		return false
	return add_item(food_data.category_id, food_data.item_id, food_data.display_name, amount, food_data.get_icon_path())


func remove_item(category_id: StringName, item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not _items_by_category.has(category_id):
		return false

	var items := _items_by_category[category_id] as Array
	for index in range(items.size()):
		var item := items[index] as Dictionary
		if item.get("id", &"") != item_id:
			continue

		var current_amount := int(item.get("amount", 0))
		if current_amount > amount:
			item["amount"] = current_amount - amount
		else:
			items.remove_at(index)
		inventory_changed.emit()
		return true

	return false


func has_category(category_id: StringName) -> bool:
	for category in _categories:
		if category.get("id", &"") == category_id:
			return true
	return false


func _setup_empty_categories() -> void:
	for category in _categories:
		var category_id: StringName = category.get("id", &"")
		if category_id == &"":
			continue
		if not _items_by_category.has(category_id):
			_items_by_category[category_id] = []
