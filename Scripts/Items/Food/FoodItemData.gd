extends Resource
class_name FoodItemData

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category_id: StringName = &"foods"
@export_range(1, 999, 1) var stack_max: int = 99
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(0, 999999, 1) var sell_price: int = 0
@export var need_effect: NeedEffectData


func get_icon_path() -> String:
	if icon == null:
		return ""
	return icon.resource_path


func get_need_effect_path() -> String:
	if need_effect == null:
		return ""
	return need_effect.resource_path


func to_inventory_entry(amount: int = 1) -> Dictionary:
	return {
		"id": item_id,
		"category_id": category_id,
		"display_name": display_name,
		"amount": max(amount, 1),
		"icon_path": get_icon_path(),
		"stack_max": stack_max,
		"description": description,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"need_effect_path": get_need_effect_path(),
	}
