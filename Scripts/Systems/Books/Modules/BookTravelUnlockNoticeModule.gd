extends Node
class_name BookTravelUnlockNoticeModule

const TRAVEL_UNLOCK_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_002.ogg"

var _notice_sfx: AudioStream


func prepare_runtime_cache() -> void:
	_get_notice_sfx()


func push_travel_unlock_notice(book: BookData) -> void:
	if book == null or not book.has_travel_unlock():
		return

	var message_log: Node = get_tree().get_first_node_in_group(&"message_log")
	if message_log == null:
		return

	var message: String = _make_travel_unlock_message(book)
	if message.is_empty():
		return

	if message_log.has_method("add_travel_unlock_message"):
		message_log.call("add_travel_unlock_message", message, _get_notice_sfx(), 0.0)
		return

	if message_log.has_method("add_log_entry"):
		message_log.call("add_log_entry", {
			"message": message,
			"channel": "normal",
			"style_id": &"travel_unlock",
			"custom_sfx": _get_notice_sfx(),
			"custom_sfx_volume_db": 0.0,
			"should_play_sfx": false,
		})
		return

	if message_log.has_method("add_message"):
		message_log.call("add_message", message)


func _make_travel_unlock_message(book: BookData) -> String:
	var location_name: String = book.get_unlock_travel_display_name().strip_edges()
	if location_name.is_empty():
		location_name = String(book.get_unlock_travel_map_id())
	if location_name.is_empty():
		return ""

	return "移動場所が解禁されました: %s\n移動メニューの探索から選べます。" % location_name


func _get_notice_sfx() -> AudioStream:
	if _notice_sfx != null:
		return _notice_sfx
	if ResourceLoader.exists(TRAVEL_UNLOCK_NOTICE_SFX_PATH):
		_notice_sfx = load(TRAVEL_UNLOCK_NOTICE_SFX_PATH) as AudioStream
	return _notice_sfx
