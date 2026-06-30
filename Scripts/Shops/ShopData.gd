extends Resource
class_name ShopData

@export var shop_id: StringName = &""
@export var display_name: String = "ショップ"
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var items: Array[ShopItemData] = []


func get_available_items() -> Array[ShopItemData]:
	var result: Array[ShopItemData] = []
	for item in items:
		if item == null:
			continue
		if not item.is_available:
			continue
		result.append(item)
	return result


func get_portrait_path() -> String:
	if portrait == null:
		return ""
	return portrait.resource_path


func is_empty() -> bool:
	return get_available_items().is_empty()
