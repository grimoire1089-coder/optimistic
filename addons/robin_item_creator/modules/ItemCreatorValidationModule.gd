@tool
extends RefCounted

const LEVEL_OK := "ok"
const LEVEL_WARNING := "warning"
const LEVEL_ERROR := "error"


static func validate_form(display_name: String, item_id: StringName, category_id: StringName, save_path: String, buy_price: int, sell_price: int, hunger_value: float, water_value: float) -> Dictionary:
	var messages := PackedStringArray()
	var has_error := false
	var has_warning := false

	var display_name_text := display_name.strip_edges()
	var item_id_text := String(item_id).strip_edges()
	var save_path_text := save_path.strip_edges()

	if display_name_text.is_empty():
		messages.append("ERROR: 表示名が未入力です。")
		has_error = true

	if item_id_text.is_empty():
		messages.append("ERROR: アイテムIDが未入力です。")
		has_error = true
	else:
		var item_id_message := _validate_item_id_text(item_id_text)
		if not item_id_message.is_empty():
			messages.append(item_id_message)
			has_error = true

	if category_id == &"":
		messages.append("ERROR: カテゴリが未選択です。")
		has_error = true

	if save_path_text.is_empty():
		messages.append("ERROR: 保存先プレビューが空です。")
		has_error = true
	else:
		var directory_path := save_path_text.get_base_dir()
		if not DirAccess.dir_exists_absolute(directory_path):
			messages.append("WARNING: 保存先フォルダがまだありません: %s" % directory_path)
			has_warning = true
		if ResourceLoader.exists(save_path_text):
			messages.append("WARNING: 同じ保存先のResourceが既にあります。保存実装時は上書き注意: %s" % save_path_text)
			has_warning = true

	if buy_price == 0 and sell_price == 0:
		messages.append("WARNING: 購入価格と売却価格がどちらも0です。")
		has_warning = true
	elif buy_price > 0 and sell_price > buy_price:
		messages.append("WARNING: 売却価格が購入価格より高いです。")
		has_warning = true

	if is_zero_approx(hunger_value) and is_zero_approx(water_value):
		messages.append("WARNING: 満腹・水分の効果がどちらも0です。")
		has_warning = true

	var level := LEVEL_OK
	if has_error:
		level = LEVEL_ERROR
	elif has_warning:
		level = LEVEL_WARNING

	if messages.is_empty():
		messages.append("OK: 入力値チェックで大きな問題は見つかりません。")

	return {
		"level": level,
		"messages": messages,
		"has_error": has_error,
		"has_warning": has_warning,
	}


static func format_result(result: Dictionary) -> String:
	var messages: PackedStringArray = result.get("messages", PackedStringArray())
	return "\n".join(messages)


static func _validate_item_id_text(item_id_text: String) -> String:
	if item_id_text != item_id_text.to_lower():
		return "ERROR: アイテムIDには小文字の英数字とアンダーバーだけを使ってください。"
	if item_id_text.begins_with("_") or item_id_text.ends_with("_"):
		return "ERROR: アイテムIDの先頭・末尾にアンダーバーは使えません。"
	if item_id_text.contains("__"):
		return "ERROR: アイテムIDに連続アンダーバーは使えません。"

	for index in range(item_id_text.length()):
		var code := item_id_text.unicode_at(index)
		var character := item_id_text.substr(index, 1)
		var is_digit := code >= 48 and code <= 57
		var is_lower_alpha := code >= 97 and code <= 122
		if is_digit or is_lower_alpha or character == "_":
			continue
		return "ERROR: アイテムIDに使えない文字があります。使えるのは a-z / 0-9 / _ だけです。"

	return ""
