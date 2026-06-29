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


func get_icon_path() -> String:
	if icon == null:
		return ""
	return icon.resource_path
