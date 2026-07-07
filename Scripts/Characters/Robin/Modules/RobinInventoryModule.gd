extends Node
class_name RobinInventoryModule

signal inventory_changed

const CATEGORY_TOOLS := &"tools"
const CATEGORY_FOODS := &"foods"
const CATEGORY_DRINKS := &"drinks"
const CATEGORY_RECIPES := &"recipes"
const CATEGORY_MATERIALS := &"materials"
const CATEGORY_INGREDIENTS := &"ingredients"
const CATEGORY_MISC := &"misc"
const UNLIMITED_SLOT_LIMIT := -1

@export var slots_per_category: int = 25
@export var tool_slots_unlimited: bool = true
@export var initial_item_paths: PackedStringArray = PackedStringArray()
@export var owner_display_name: String = ""
@export var owned_item_ids: PackedStringArray = PackedStringArray(["tool_0001_lapis"])
@export var owned_item_name_format: String = "%sの%s"

var _categories: Array[Dictionary] = [
	{"id": CATEGORY_TOOLS, "display_name": "ツール"},
	{"id": CATEGORY_FOODS, "display_name": "食品"},
	{"id": CATEGORY_DRINKS, "display_name": "飲料"},
	{"id": CATEGORY_RECIPES, "display_name": "レシピ"},
	{"id": CATEGORY_MATERIALS, "display_name": "素材"},
	{"id": CATEGORY_INGREDIENTS, "display_name": "食材"},
	{"id": CATEGORY_MISC, "display_name": "雑貨"},
]

var _items_by_category: Dictionary = {}
var _initial_items_added := false


func _ready() -> void:
	_setup_empty_categories()
	_add_initial_items_once()


func get_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in _categories:
		result.append((category as Dictionary).duplicate(true))
	return result


func get_slots_per_category() -> int:
	return max(slots_per_category, 0)


func get_slot_limit(category_id: StringName) -> int:
	if tool_slots_unlimited and category_id == CATEGORY_TOOLS:
		return UNLIMITED_SLOT_LIMIT
	return get_slots_per_category()


func has_slot_limit(category_id: StringName) -> bool:
	return get_slot_limit(category_id) != UNLIMITED_SLOT_LIMIT


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


func add_item(
	category_id: StringName,
	item_id: StringName,
	display_name: String,
	amount: int = 1,
	icon_path: String = "",
	stack_max: int = 99,
	description: String = "",
	buy_price: int = 0,
	sell_price: int = 0,
	need_effect_path: String = "",
	can_discard: bool = true,
	can_transfer: bool = true,
	nutrition_value: float = 0.0,
	hydration_value: float = 0.0,
	extra_need_values: Dictionary = {},
	need_values: Dictionary = {},
	item_owner_display_name: String = "",
	base_display_name: String = ""
) -> bool:
	if amount <= 0:
		return false
	if not has_category(category_id):
		push_warning("存在しないインベントリカテゴリです: %s" % category_id)
		return false

	_setup_empty_categories()
	var safe_need_values := _copy_need_values(need_values)
	var safe_extra_need_values := _copy_need_values(extra_need_values)
	var safe_base_display_name := base_display_name if not base_display_name.strip_edges().is_empty() else display_name
	var items := _items_by_category[category_id] as Array
	for item in items:
		if item.get("id", &"") == item_id:
			var safe_stack_max := maxi(stack_max, 1)
			item["amount"] = mini(int(item.get("amount", 0)) + amount, safe_stack_max)
			item["display_name"] = display_name
			item["base_display_name"] = safe_base_display_name
			item["owner_display_name"] = item_owner_display_name
			item["stack_max"] = safe_stack_max
			item["description"] = description
			item["buy_price"] = buy_price
			item["sell_price"] = sell_price
			item["need_effect_path"] = need_effect_path
			item["can_discard"] = can_discard
			item["can_transfer"] = can_transfer
			item["nutrition_value"] = nutrition_value
			item["hydration_value"] = hydration_value
			item["extra_need_values"] = safe_extra_need_values
			item["need_values"] = safe_need_values
			_notify_food_encyclopedia_if_needed(category_id, item_id, display_name)
			inventory_changed.emit()
			return true

	var slot_limit := get_slot_limit(category_id)
	if slot_limit != UNLIMITED_SLOT_LIMIT and items.size() >= slot_limit:
		push_warning("インベントリがいっぱいです: %s" % category_id)
		return false

	items.append({
		"id": item_id,
		"category_id": category_id,
		"display_name": display_name,
		"base_display_name": safe_base_display_name,
		"owner_display_name": item_owner_display_name,
		"amount": amount,
		"icon_path": icon_path,
		"stack_max": maxi(stack_max, 1),
		"description": description,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"need_effect_path": need_effect_path,
		"can_discard": can_discard,
		"can_transfer": can_transfer,
		"nutrition_value": nutrition_value,
		"hydration_value": hydration_value,
		"extra_need_values": safe_extra_need_values,
		"need_values": safe_need_values,
	})
	_notify_food_encyclopedia_if_needed(category_id, item_id, display_name)
	inventory_changed.emit()
	return true


func add_food_item(food_data: FoodItemData, amount: int = 1) -> bool:
	if food_data == null:
		push_warning("食品データが空です。")
		return false
	if food_data.item_id == &"":
		push_warning("食品IDが空です。")
		return false
	var item_owner_name := _get_item_owner_display_name(food_data.item_id)
	var item_display_name := _get_owned_item_display_name(food_data.item_id, food_data.display_name, item_owner_name)
	return add_item(
		food_data.category_id,
		food_data.item_id,
		item_display_name,
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
		item_owner_name,
		food_data.display_name
	)


func remove_item(category_id: StringName, item_id: StringName, amount: int = 1, force: bool = false) -> bool:
	if amount <= 0:
		return false
	if not _items_by_category.has(category_id):
		return false

	var items := _items_by_category[category_id] as Array
	for index in range(items.size()):
		var item := items[index] as Dictionary
		if item.get("id", &"") != item_id:
			continue

		if not force and not bool(item.get("can_discard", true)):
			return false

		var current_amount := int(item.get("amount", 0))
		if current_amount > amount:
			item["amount"] = current_amount - amount
		else:
			items.remove_at(index)
		inventory_changed.emit()
		return true

	return false


func can_discard_item(category_id: StringName, item_id: StringName) -> bool:
	var item := _find_item_entry(category_id, item_id)
	if item.is_empty():
		return false
	return bool(item.get("can_discard", true))


func can_transfer_item(category_id: StringName, item_id: StringName) -> bool:
	var item := _find_item_entry(category_id, item_id)
	if item.is_empty():
		return false
	return bool(item.get("can_transfer", true))


func has_category(category_id: StringName) -> bool:
	for category in _categories:
		if category.get("id", &"") == category_id:
			return true
	return false


func _setup_empty_categories() -> void:
	for category in _categories:
		var category_id: StringName = category.get("id", &"")
		if not _items_by_category.has(category_id):
			_items_by_category[category_id] = []


func _add_initial_items_once() -> void:
	if _initial_items_added:
		return
	_initial_items_added = true
	for item_path in initial_item_paths:
		_add_item_from_resource_path(String(item_path))


func _add_item_from_resource_path(item_path: String) -> void:
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		return
	var resource := load(item_path)
	if resource is FoodItemData:
		add_food_item(resource as FoodItemData, 1)
		return
	if resource != null and resource.has_method("to_inventory_item"):
		var item_data: Dictionary = resource.call("to_inventory_item")
		var item_id: StringName = item_data.get("id", &"")
		var raw_display_name := String(item_data.get("display_name", ""))
		var item_owner_name := _get_item_owner_display_name(item_id)
		var item_display_name := _get_owned_item_display_name(item_id, raw_display_name, item_owner_name)
		add_item(
			item_data.get("category_id", CATEGORY_TOOLS),
			item_id,
			item_display_name,
			int(item_data.get("amount", 1)),
			item_data.get("icon_path", ""),
			int(item_data.get("stack_max", 1)),
			item_data.get("description", ""),
			int(item_data.get("buy_price", 0)),
			int(item_data.get("sell_price", 0)),
			item_data.get("need_effect_path", ""),
			bool(item_data.get("can_discard", true)),
			bool(item_data.get("can_transfer", true)),
			float(item_data.get("nutrition_value", 0.0)),
			float(item_data.get("hydration_value", 0.0)),
			item_data.get("extra_need_values", {}),
			item_data.get("need_values", {}),
			item_owner_name,
			raw_display_name
		)


func _find_item_entry(category_id: StringName, item_id: StringName) -> Dictionary:
	if not _items_by_category.has(category_id):
		return {}
	var items := _items_by_category[category_id] as Array
	for item in items:
		if item is Dictionary and item.get("id", &"") == item_id:
			return item as Dictionary
	return {}


func _get_item_owner_display_name(item_id: StringName) -> String:
	if owner_display_name.strip_edges().is_empty():
		return ""
	if not _is_owned_item(item_id):
		return ""
	return owner_display_name.strip_edges()


func _get_owned_item_display_name(item_id: StringName, base_name: String, item_owner_name: String) -> String:
	if item_owner_name.strip_edges().is_empty():
		return base_name
	if base_name.strip_edges().is_empty():
		return base_name
	if owned_item_name_format.find("%s") == -1:
		return "%sの%s" % [item_owner_name, base_name]
	return owned_item_name_format % [item_owner_name, base_name]


func _is_owned_item(item_id: StringName) -> bool:
	var item_id_text := String(item_id)
	for owned_id in owned_item_ids:
		if String(owned_id) == item_id_text:
			return true
	return false


func _copy_need_values(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values.keys():
		result[StringName(String(key))] = float(values[key])
	return result


func _notify_food_encyclopedia_if_needed(category_id: StringName, item_id: StringName, display_name: String) -> void:
	if category_id != CATEGORY_FOODS and category_id != CATEGORY_DRINKS:
		return
	var encyclopedia := get_node_or_null("/root/FoodEncyclopedia")
	if encyclopedia == null or not encyclopedia.has_method("register_food_discovered"):
		return
	encyclopedia.call("register_food_discovered", item_id, display_name)
