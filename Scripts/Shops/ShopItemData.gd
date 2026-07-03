extends Resource
class_name ShopItemData

const BOOK_CATEGORY_ID := &"books"

@export var item_data: Resource
@export var shop_tab_id: StringName = &""
@export_range(1, 999, 1) var amount: int = 1
@export_range(-1, 999999, 1) var price_override: int = -1
@export var custom_display_name: String = ""
@export_multiline var custom_description: String = ""
@export var is_available: bool = true


func get_item_id() -> StringName:
	if item_data == null:
		return &""
	if item_data.has_method("get_item_id"):
		var method_value = item_data.call("get_item_id")
		if method_value is StringName:
			return method_value
		return StringName(String(method_value))
	var value = item_data.get("item_id")
	if value == null:
		value = item_data.get("book_id")
	if value == null:
		return &""
	if value is StringName:
		return value
	return StringName(String(value))


func get_category_id() -> StringName:
	if item_data == null:
		return &"foods"
	var value = item_data.get("category_id")
	if value is StringName:
		return value
	if value == null:
		return &"foods"
	return StringName(String(value))


func get_shop_tab_id() -> StringName:
	if shop_tab_id != &"":
		return shop_tab_id
	return get_category_id()


func get_book_data() -> BookData:
	if item_data is BookData:
		return item_data as BookData
	return null


func is_book_product() -> bool:
	return get_book_data() != null or get_category_id() == BOOK_CATEGORY_ID


func get_display_name() -> String:
	if custom_display_name != "":
		return custom_display_name
	if item_data == null:
		return "商品"
	return String(item_data.get("display_name"))


func get_description() -> String:
	if custom_description != "":
		return custom_description
	if item_data == null:
		return ""
	return String(item_data.get("description"))


func get_unit_price() -> int:
	if price_override >= 0:
		return price_override
	if item_data == null:
		return 0
	return max(int(item_data.get("buy_price")), 0)


func get_total_price() -> int:
	return get_unit_price() * max(amount, 1)


func get_icon_path() -> String:
	if item_data == null:
		return ""
	if item_data.has_method("get_icon_path"):
		return String(item_data.call("get_icon_path"))
	var icon = item_data.get("icon")
	if icon is Texture2D:
		return (icon as Texture2D).resource_path
	return ""
