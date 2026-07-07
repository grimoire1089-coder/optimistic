extends Node
class_name FoodEncyclopediaUnlockNoticeModule

const STYLER_NODE_NAME := "FoodEncyclopediaUnlockLogStyler"
const NORMAL_LOG_CHANNEL := 0
const FOOD_UNLOCK_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_002.ogg"


func push_food_unlock_notice(item_id: StringName, display_name: String = "") -> void:
	if item_id == &"" and display_name.strip_edges().is_empty():
		return

	var message_log: Node = get_tree().get_first_node_in_group(&"message_log")
	if message_log == null:
		return

	var message: String = _make_food_unlock_message(item_id, display_name)
	if message.is_empty():
		return

	var styler: FoodEncyclopediaUnlockLogStyler = _ensure_styler(message_log)
	if styler != null:
		styler.register_message(message)

	if _queue_normal_message_without_default_sfx(message_log, message):
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


func _queue_normal_message_without_default_sfx(message_log: Node, message: String) -> bool:
	if message_log == null or not message_log.has_method("_queue_message_to_channel"):
		return false
	message_log.call("_queue_message_to_channel", message, NORMAL_LOG_CHANNEL, false)
	return true


func _ensure_styler(message_log: Node) -> FoodEncyclopediaUnlockLogStyler:
	if message_log == null:
		return null

	var existing := message_log.get_node_or_null(STYLER_NODE_NAME) as FoodEncyclopediaUnlockLogStyler
	if existing != null:
		return existing

	var styler := FoodEncyclopediaUnlockLogStyler.new()
	styler.name = STYLER_NODE_NAME
	message_log.add_child(styler)
	styler.setup(message_log)
	return styler


class FoodEncyclopediaUnlockLogStyler extends Node:
	const GOLD_BACKGROUND_COLOR := Color(0.060, 0.048, 0.024, 0.98)
	const GOLD_BORDER_COLOR := Color(1.00, 0.76, 0.18, 0.98)
	const GOLD_BORDER_WIDTH := 2
	const CARD_CORNER_RADIUS := 10

	var _message_log: Node
	var _message_texts: Dictionary = {}
	var _pending_message_texts: Dictionary = {}
	var _played_message_texts: Dictionary = {}
	var _message_list: VBoxContainer
	var _notice_sfx: AudioStream
	var _gold_style: StyleBoxFlat


	func setup(message_log: Node) -> void:
		_message_log = message_log
		_load_food_unlock_notice_sfx()
		_connect_message_list_signal()


	func register_message(message: String) -> void:
		var key := message.strip_edges()
		if key.is_empty():
			return
		_message_texts[key] = true
		_pending_message_texts[key] = true


	func _connect_message_list_signal() -> void:
		var list := _get_message_list()
		if list == null:
			return
		var callable := Callable(self, "_on_message_list_child_entered_tree")
		if not list.child_entered_tree.is_connected(callable):
			list.child_entered_tree.connect(callable)


	func _on_message_list_child_entered_tree(child: Node) -> void:
		_try_apply_gold_style_to_holder(child)


	func _try_apply_gold_style_to_holder(holder: Node) -> void:
		if holder == null:
			return
		if _message_texts.is_empty():
			return

		var card := _find_panel_container(holder)
		if card == null:
			return

		var message_text := _find_message_text(card)
		if message_text.is_empty() or not _message_texts.has(message_text):
			return

		_apply_gold_style(card)
		if _pending_message_texts.has(message_text):
			_pending_message_texts.erase(message_text)
			_play_notice_for_message_if_needed(message_text)


	func _get_message_list() -> VBoxContainer:
		if _message_list != null and is_instance_valid(_message_list):
			return _message_list
		if _message_log == null or not is_instance_valid(_message_log):
			return null
		var value: Variant = _message_log.get("message_list")
		if value is VBoxContainer:
			_message_list = value as VBoxContainer
		return _message_list


	func _find_panel_container(node: Node) -> PanelContainer:
		if node == null:
			return null
		if node is PanelContainer:
			return node as PanelContainer
		for child in node.get_children():
			var found := _find_panel_container(child)
			if found != null:
				return found
		return null


	func _find_message_text(node: Node) -> String:
		if node == null:
			return ""
		if node is Label:
			var label := node as Label
			var text := label.text.strip_edges()
			if not text.is_empty() and not text.begins_with("発行:"):
				return text
		for child in node.get_children():
			var found := _find_message_text(child)
			if not found.is_empty():
				return found
		return ""


	func _apply_gold_style(card: PanelContainer) -> void:
		if card == null:
			return
		card.add_theme_stylebox_override("panel", _get_gold_style())


	func _get_gold_style() -> StyleBoxFlat:
		if _gold_style != null:
			return _gold_style
		_gold_style = StyleBoxFlat.new()
		_gold_style.bg_color = GOLD_BACKGROUND_COLOR
		_gold_style.border_color = GOLD_BORDER_COLOR
		_gold_style.set_border_width_all(GOLD_BORDER_WIDTH)
		_gold_style.set_corner_radius_all(CARD_CORNER_RADIUS)
		_gold_style.set_content_margin_all(0.0)
		return _gold_style


	func _load_food_unlock_notice_sfx() -> void:
		if _notice_sfx != null:
			return
		if ResourceLoader.exists(FOOD_UNLOCK_NOTICE_SFX_PATH):
			_notice_sfx = load(FOOD_UNLOCK_NOTICE_SFX_PATH) as AudioStream


	func _play_notice_for_message_if_needed(message_text: String) -> void:
		if message_text.is_empty() or _played_message_texts.has(message_text):
			return
		_played_message_texts[message_text] = true
		if _notice_sfx == null:
			return
		AudioPlayer.play_sfx(_notice_sfx, 1.0, 0.0)
