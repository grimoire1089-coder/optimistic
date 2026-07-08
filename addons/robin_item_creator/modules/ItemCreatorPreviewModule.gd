@tool
extends RefCounted

const DEFAULT_ITEM_ID := "new_item"

const CATEGORY_DATA := [
	{"id": &"foods", "label": "食品", "directory": "res://Data/Items/Food", "prefix": "food"},
	{"id": &"drinks", "label": "飲料", "directory": "res://Data/Items/Food", "prefix": "drink"},
	{"id": &"ingredients", "label": "食材", "directory": "res://Data/Items/Ingredients", "prefix": "ingredient"},
	{"id": &"materials", "label": "素材", "directory": "res://Data/Items/Materials", "prefix": "material"},
	{"id": &"tools", "label": "ツール", "directory": "res://Data/Items/Tools", "prefix": "tool"},
	{"id": &"misc", "label": "雑貨", "directory": "res://Data/Items/Misc", "prefix": "item"},
]


static func get_category_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in CATEGORY_DATA:
		result.append((category as Dictionary).duplicate(true))
	return result


static func get_category_label(category_id: StringName) -> String:
	var data := _find_category_data(category_id)
	return String(data.get("label", String(category_id)))


static func get_save_directory(category_id: StringName) -> String:
	var data := _find_category_data(category_id)
	return String(data.get("directory", "res://Data/Items/Misc"))


static func get_id_prefix(category_id: StringName) -> String:
	var data := _find_category_data(category_id)
	return String(data.get("prefix", "item"))


static func build_item_id(display_name: String, category_id: StringName) -> StringName:
	var normalized := normalize_id_text(display_name)
	if normalized.is_empty() or normalized == DEFAULT_ITEM_ID:
		normalized = "%s_%s" % [get_id_prefix(category_id), DEFAULT_ITEM_ID]
	return StringName(normalized)


static func build_save_path(category_id: StringName, item_id: StringName) -> String:
	var item_id_text := normalize_id_text(String(item_id))
	if item_id_text.is_empty():
		item_id_text = "%s_%s" % [get_id_prefix(category_id), DEFAULT_ITEM_ID]
	return "%s/%s.tres" % [get_save_directory(category_id), item_id_text]


static func normalize_id_text(text: String) -> String:
	var source := text.strip_edges().to_lower()
	if source.is_empty():
		return ""

	var result := ""
	var last_was_separator := false
	for index in range(source.length()):
		var code := source.unicode_at(index)
		var character := source.substr(index, 1)
		var is_digit := code >= 48 and code <= 57
		var is_lower_alpha := code >= 97 and code <= 122
		if is_digit or is_lower_alpha:
			result += character
			last_was_separator = false
		elif character == "_" or character == "-" or character == " ":
			if not last_was_separator and not result.is_empty():
				result += "_"
			last_was_separator = true

	result = result.strip_edges().trim_suffix("_")
	return result


static func get_preview_summary(display_name: String, item_id: StringName, category_id: StringName, buy_price: int, sell_price: int, hunger_value: float, water_value: float) -> String:
	var lines := PackedStringArray()
	lines.append("名前: %s" % _fallback_text(display_name, "未入力"))
	lines.append("ID: %s" % _fallback_text(String(item_id), "未入力"))
	lines.append("カテゴリ: %s (%s)" % [get_category_label(category_id), String(category_id)])
	lines.append("保存先: %s" % build_save_path(category_id, item_id))
	lines.append("価格: 買値 %d / 売値 %d" % [maxi(buy_price, 0), maxi(sell_price, 0)])
	lines.append("効果: hunger +%s / water +%s" % [_format_float(hunger_value), _format_float(water_value)])
	return "\n".join(lines)


static func _find_category_data(category_id: StringName) -> Dictionary:
	for category in CATEGORY_DATA:
		var category_data := category as Dictionary
		if category_data.get("id", &"") == category_id:
			return category_data
	return CATEGORY_DATA[0].duplicate(true)


static func _fallback_text(text: String, fallback: String) -> String:
	if text.strip_edges().is_empty():
		return fallback
	return text.strip_edges()


static func _format_float(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value
