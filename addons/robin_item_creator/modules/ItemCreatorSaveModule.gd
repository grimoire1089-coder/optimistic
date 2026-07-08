@tool
extends RefCounted

const FoodItemDataScript := preload("res://Scripts/Items/Food/FoodItemData.gd")


static func save_food_item(payload: Dictionary, save_path: String) -> Dictionary:
	var normalized_path := save_path.strip_edges()
	if normalized_path.is_empty():
		return _error_result("保存先が空です。")
	if not normalized_path.begins_with("res://"):
		return _error_result("保存先は res:// から始まるパスにしてください: %s" % normalized_path)
	if not normalized_path.ends_with(".tres"):
		return _error_result("保存先は .tres ファイルにしてください: %s" % normalized_path)
	if ResourceLoader.exists(normalized_path):
		return _error_result("同じ保存先のResourceが既にあります。上書きはしません: %s" % normalized_path)

	var directory_error := _ensure_resource_directory(normalized_path.get_base_dir())
	if directory_error != OK:
		return _error_result("保存先フォルダの作成に失敗しました: %s / error=%d" % [normalized_path.get_base_dir(), directory_error])

	var item: FoodItemData = FoodItemDataScript.new()
	item.item_id = StringName(String(payload.get("item_id", "")).strip_edges())
	item.display_name = String(payload.get("display_name", "")).strip_edges()
	item.description = String(payload.get("description", ""))
	item.category_id = StringName(String(payload.get("category_id", "foods")).strip_edges())
	item.stack_max = int(payload.get("stack_max", 99))
	item.buy_price = maxi(int(payload.get("buy_price", 0)), 0)
	item.sell_price = maxi(int(payload.get("sell_price", 0)), 0)
	item.can_discard = bool(payload.get("can_discard", true))
	item.can_transfer = bool(payload.get("can_transfer", true))
	item.nutrition_value = maxf(float(payload.get("nutrition_value", 0.0)), 0.0)
	item.hydration_value = maxf(float(payload.get("hydration_value", 0.0)), 0.0)
	item.extra_need_values = {}
	item.resource_path = normalized_path

	var save_error := ResourceSaver.save(item, normalized_path)
	if save_error != OK:
		return _error_result("FoodItemDataの保存に失敗しました: %s / error=%d" % [normalized_path, save_error])

	return {
		"ok": true,
		"message": "保存しました: %s" % normalized_path,
		"path": normalized_path,
		"error": OK,
	}


static func build_food_payload(display_name: String, item_id: StringName, category_id: StringName, description: String, buy_price: int, sell_price: int, hunger_value: float, water_value: float) -> Dictionary:
	return {
		"item_id": String(item_id).strip_edges(),
		"display_name": display_name.strip_edges(),
		"description": description,
		"category_id": String(category_id),
		"stack_max": 99,
		"buy_price": maxi(buy_price, 0),
		"sell_price": maxi(sell_price, 0),
		"can_discard": true,
		"can_transfer": true,
		"nutrition_value": maxf(hunger_value, 0.0),
		"hydration_value": maxf(water_value, 0.0),
	}


static func _ensure_resource_directory(res_directory_path: String) -> int:
	var directory_path := res_directory_path.strip_edges()
	if directory_path.is_empty():
		return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(directory_path):
		return OK

	var absolute_directory_path := ProjectSettings.globalize_path(directory_path)
	if DirAccess.dir_exists_absolute(absolute_directory_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(absolute_directory_path)


static func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"path": "",
		"error": FAILED,
	}
