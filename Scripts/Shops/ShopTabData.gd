extends Resource
class_name ShopTabData

@export var tab_id: StringName = &""
@export var display_name: String = "タブ"


func is_valid() -> bool:
	return tab_id != &""
