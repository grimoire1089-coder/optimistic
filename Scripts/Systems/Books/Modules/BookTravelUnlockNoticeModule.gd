extends Node
class_name BookTravelUnlockNoticeModule

const STYLER_NODE_NAME := "TravelUnlockLogStyler"
const NORMAL_LOG_CHANNEL := 0


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
		message_log.call("add_travel_unlock_message", message)
		return

	var styler: TravelUnlockLogStyler = _ensure_styler(message_log)
	if styler != null:
		styler.register_message(message)

	if message_log.has_method("add_message"):
		message_log.call("add_message", message)

	if styler != null:
		styler.apply_gold_styles_deferred()


func _make_travel_unlock_message(book: BookData) -> String:
	var location_name: String = book.get_unlock_travel_display_name().strip_edges()
	if location_name.is_empty():
		location_name = String(book.get_unlock_travel_map_id())
	if location_name.is_empty():
		return ""

	var message := "移動場所が解禁されました: %s" % location_name
	var description := book.unlock_travel_description.strip_edges()
	if not description.is_empty():
		message += "\n%s" % description
	message += "\n移動メニューの探索から選べます。"
	return message


func _ensure_styler(message_log: Node) -> TravelUnlockLogStyler:
	if message_log == null:
		return null

	var existing := message_log.get_node_or_null(STYLER_NODE_NAME) as TravelUnlockLogStyler
	if existing != null:
		return existing

	var styler := TravelUnlockLogStyler.new()
	styler.name = STYLER_NODE_NAME
	message_log.add_child(styler)
	styler.setup(message_log)
	return styler


class TravelUnlockLogStyler extends Node:
	const GOLD_BACKGROUND_COLOR := Color(0.060, 0.048, 0.024, 0.98)
	const GOLD_BORDER_COLOR := Color(1.00, 0.76, 0.18, 0.98)
	const GOLD_BORDER_WIDTH := 2
	const CARD_CORNER_RADIUS := 10

	var _message_log: Node
	var _message_texts: Dictionary = {}
	var _message_list: VBoxContainer
	var _tab_bar: TabBar


	func setup(message_log: Node) -> void:
		_message_log = message_log
		_connect_message_list_signal()
		_connect_tab_signal()
		apply_gold_styles_deferred()


	func register_message(message: String) -> void:
		var key := message.strip_edges()
		if key.is_empty():
			return
		_message_texts[key] = true
		apply_gold_styles_deferred()


	func apply_gold_styles_deferred() -> void:
		call_deferred("apply_gold_styles")


	func apply_gold_styles() -> void:
		if _message_log == null or not is_instance_valid(_message_log):
			return
		if int(_message_log.get("_current_channel")) != NORMAL_LOG_CHANNEL:
			return

		var list := _get_message_list()
		if list == null:
			return

		for holder in list.get_children():
			var card := _find_panel_container(holder)
			if card == null:
				continue
			var message_text := _find_message_text(card)
			if message_text.is_empty() or not _message_texts.has(message_text):
				continue
			_apply_gold_style(card)


	func _connect_message_list_signal() -> void:
		var list := _get_message_list()
		if list == null:
			return
		var callable := Callable(self, "_on_message_list_child_entered_tree")
		if not list.child_entered_tree.is_connected(callable):
			list.child_entered_tree.connect(callable)


	func _connect_tab_signal() -> void:
		var tab_bar := _get_tab_bar()
		if tab_bar == null:
			return
		var callable := Callable(self, "_on_log_tab_changed")
		if not tab_bar.tab_changed.is_connected(callable):
			tab_bar.tab_changed.connect(callable)


	func _on_message_list_child_entered_tree(_child: Node) -> void:
		apply_gold_styles_deferred()


	func _on_log_tab_changed(_tab: int) -> void:
		apply_gold_styles_deferred()


	func _get_message_list() -> VBoxContainer:
		if _message_list != null and is_instance_valid(_message_list):
			return _message_list
		if _message_log == null or not is_instance_valid(_message_log):
			return null
		var value: Variant = _message_log.get("message_list")
		if value is VBoxContainer:
			_message_list = value as VBoxContainer
		return _message_list


	func _get_tab_bar() -> TabBar:
		if _tab_bar != null and is_instance_valid(_tab_bar):
			return _tab_bar
		if _message_log == null or not is_instance_valid(_message_log):
			return null
		var value: Variant = _message_log.get("tab_bar")
		if value is TabBar:
			_tab_bar = value as TabBar
		return _tab_bar


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
		card.add_theme_stylebox_override("panel", _make_gold_style())


	func _make_gold_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD_BACKGROUND_COLOR
		style.border_color = GOLD_BORDER_COLOR
		style.set_border_width_all(GOLD_BORDER_WIDTH)
		style.set_corner_radius_all(CARD_CORNER_RADIUS)
		style.set_content_margin_all(0.0)
		return style
