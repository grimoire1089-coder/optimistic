extends Node
class_name FoodEncyclopediaUnlockNoticeModule

const FOOD_UNLOCK_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_002.ogg"

var _notice_sfx: AudioStream


func prepare_runtime_cache() -> void:
	_get_notice_sfx()


func push_food_unlock_notice(item_id: StringName, display_name: String = "") -> void:
	if item_id == &"" and display_name.strip_edges().is_empty():
		return

	var message_log: Node = get_tree().get_first_node_in_group(&"message_log")
	if message_log == null:
		return

	var message: String = _make_food_unlock_message(item_id, display_name)
	if message.is_empty():
		return

	if message_log.has_method("add_food_encyclopedia_unlock_message"):
		message_log.call("add_food_encyclopedia_unlock_message", message, _get_notice_sfx(), 0.0)
		return

	if message_log.has_method("add_message"):
		message_log.call("add_message", message)


func _make_food_unlock_message(item_id: StringName, display_name: String) -> String:
	var safe_name := display_name.strip_edges()
	if safe_name.is_empty():
		safe_name = String(item_id)
	if safe_name.is_empty():
		return ""
	return "食品図鑑に登録: %s\n食品タブで確認できます。" % safe_name


func _get_notice_sfx() -> AudioStream:
	if _notice_sfx != null:
		return _notice_sfx
	if ResourceLoader.exists(FOOD_UNLOCK_NOTICE_SFX_PATH):
		_notice_sfx = load(FOOD_UNLOCK_NOTICE_SFX_PATH) as AudioStream
	return _notice_sfx
