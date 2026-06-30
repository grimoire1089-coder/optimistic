extends PanelContainer
class_name MessageLogPanel

const DEFAULT_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_001.ogg"

enum LogChannel { NORMAL, DEBUG }

@export_range(1, 300, 1) var max_messages: int = 100
@export var notice_sfx: AudioStream
@export var notice_sfx_volume_db: float = 0.0
@export var auto_scroll_to_latest: bool = true
@export var play_notice_sfx_for_debug: bool = false
@export var card_height: float = 58.0
@export var card_enter_offset_y: float = 18.0
@export var card_enter_duration: float = 0.22
@export var card_background_color: Color = Color(0.035, 0.04, 0.06, 0.96)
@export var card_border_color: Color = Color(0.14, 0.8, 0.95, 0.9)
@export var card_text_color: Color = Color(0.92, 0.98, 1.0, 1.0)
@export var debug_card_background_color: Color = Color(0.045, 0.035, 0.055, 0.96)
@export var debug_card_border_color: Color = Color(0.95, 0.65, 0.22, 0.92)
@export var debug_card_text_color: Color = Color(1.0, 0.92, 0.78, 1.0)

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var tab_bar: TabBar = %LogTabBar
@onready var empty_label: Label = %EmptyLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var message_list: VBoxContainer = %MessageList

var _normal_messages: Array[String] = []
var _debug_messages: Array[String] = []
var _current_channel: int = LogChannel.NORMAL


func _ready() -> void:
	add_to_group(&"message_log")
	_load_default_notice_sfx_if_needed()
	_setup_tabs()
	_apply_bottom_stack_layout()
	_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()


func add_message(message: String) -> void:
	_add_message_to_channel(message, LogChannel.NORMAL, true)


func add_debug_message(message: String) -> void:
	_add_message_to_channel(message, LogChannel.DEBUG, play_notice_sfx_for_debug)


func add_debug_result(source: String, action: String, success: bool, detail: String = "") -> void:
	var status_text := "SUCCESS" if success else "FAILED"
	var result_message := "[%s] %s: %s" % [source, action, status_text]
	if not detail.strip_edges().is_empty():
		result_message += " / %s" % detail.strip_edges()
	add_debug_message(result_message)


func add_messages(messages: PackedStringArray) -> void:
	for message in messages:
		add_message(message)


func add_debug_messages(messages: PackedStringArray) -> void:
	for message in messages:
		add_debug_message(message)


func clear_messages() -> void:
	_normal_messages.clear()
	if _current_channel == LogChannel.NORMAL:
		_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()


func clear_debug_messages() -> void:
	_debug_messages.clear()
	if _current_channel == LogChannel.DEBUG:
		_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()


func clear_all_messages() -> void:
	_normal_messages.clear()
	_debug_messages.clear()
	_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()


func get_messages() -> PackedStringArray:
	return _to_packed_string_array(_normal_messages)


func get_debug_messages() -> PackedStringArray:
	return _to_packed_string_array(_debug_messages)


func switch_to_normal_log() -> void:
	_set_current_channel(LogChannel.NORMAL)


func switch_to_debug_log() -> void:
	_set_current_channel(LogChannel.DEBUG)


func _add_message_to_channel(message: String, channel: int, should_play_sfx: bool) -> void:
	var trimmed_message := message.strip_edges()
	if trimmed_message.is_empty():
		return

	var messages := _get_messages_for_channel(channel)
	messages.append(trimmed_message)

	if channel == _current_channel:
		_create_message_card(trimmed_message, channel, true)

	_trim_old_messages(channel)
	_update_header()
	_update_empty_state()

	if should_play_sfx:
		_play_notice_sfx()

	if auto_scroll_to_latest and channel == _current_channel:
		call_deferred("_scroll_to_latest")


func _setup_tabs() -> void:
	if tab_bar == null:
		return
	while tab_bar.tab_count > 0:
		tab_bar.remove_tab(0)
	tab_bar.add_tab("通常")
	tab_bar.add_tab("デバッグ")
	tab_bar.current_tab = _current_channel
	var callable := Callable(self, "_on_log_tab_changed")
	if not tab_bar.tab_changed.is_connected(callable):
		tab_bar.tab_changed.connect(callable)


func _on_log_tab_changed(tab: int) -> void:
	_set_current_channel(tab)


func _set_current_channel(channel: int) -> void:
	if channel != LogChannel.NORMAL and channel != LogChannel.DEBUG:
		return
	if _current_channel == channel:
		return
	_current_channel = channel
	_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()
	if auto_scroll_to_latest:
		call_deferred("_scroll_to_latest")


func _apply_bottom_stack_layout() -> void:
	if message_list == null:
		return
	message_list.alignment = BoxContainer.ALIGNMENT_END


func _rebuild_visible_messages(animate_cards: bool) -> void:
	if message_list == null:
		return
	for child in message_list.get_children():
		message_list.remove_child(child)
		child.queue_free()

	for message in _get_messages_for_channel(_current_channel):
		_create_message_card(message, _current_channel, animate_cards)


func _create_message_card(message: String, channel: int, animate_card: bool) -> void:
	var holder := Control.new()
	holder.clip_contents = true
	holder.custom_minimum_size = Vector2(0.0, 0.0 if animate_card else card_height)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card := _make_card_node(message, channel, animate_card)
	holder.add_child(card)
	message_list.add_child(holder)

	if animate_card:
		call_deferred("_animate_message_card", holder, card)


func _make_card_node(message: String, channel: int, animate_card: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, card_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.anchor_left = 0.0
	card.anchor_top = 1.0
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 0.0
	card.offset_right = 0.0
	if animate_card:
		card.offset_top = -card_height + card_enter_offset_y
		card.offset_bottom = card_enter_offset_y
		card.modulate.a = 0.0
	else:
		card.offset_top = -card_height
		card.offset_bottom = 0.0
		card.modulate.a = 1.0
	card.add_theme_stylebox_override("panel", _make_card_style(channel))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _get_card_text_color(channel))
	label.add_theme_font_size_override("font_size", 14)
	margin.add_child(label)

	return card


func _animate_message_card(holder: Control, card: PanelContainer) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(card):
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "custom_minimum_size:y", card_height, card_enter_duration)
	tween.tween_property(card, "offset_top", -card_height, card_enter_duration)
	tween.tween_property(card, "offset_bottom", 0.0, card_enter_duration)
	tween.tween_property(card, "modulate:a", 1.0, card_enter_duration)


func _trim_old_messages(channel: int) -> void:
	var messages := _get_messages_for_channel(channel)
	while messages.size() > max_messages:
		messages.pop_front()
		if channel == _current_channel:
			_remove_oldest_card()


func _remove_oldest_card() -> void:
	if message_list.get_child_count() <= 0:
		return
	var oldest_card_holder := message_list.get_child(0)
	message_list.remove_child(oldest_card_holder)
	oldest_card_holder.queue_free()


func _update_header() -> void:
	if title_label != null:
		title_label.text = "Message Log"
	if count_label != null:
		count_label.text = "%d/%d" % [_get_current_messages_count(), max_messages]
	if tab_bar != null and tab_bar.current_tab != _current_channel:
		tab_bar.current_tab = _current_channel


func _update_empty_state() -> void:
	var is_empty := _get_current_messages_count() <= 0
	if empty_label != null:
		empty_label.visible = is_empty
		empty_label.text = "通常ログはありません" if _current_channel == LogChannel.NORMAL else "デバッグログはありません"
	if scroll_container != null:
		scroll_container.visible = not is_empty


func _scroll_to_latest() -> void:
	await get_tree().process_frame
	if scroll_container == null:
		return
	var vertical_scroll_bar := scroll_container.get_v_scroll_bar()
	if vertical_scroll_bar == null:
		return
	scroll_container.scroll_vertical = int(vertical_scroll_bar.max_value)


func _play_notice_sfx() -> void:
	if notice_sfx == null:
		return
	AudioPlayer.play_sfx(notice_sfx, 1.0, notice_sfx_volume_db)


func _load_default_notice_sfx_if_needed() -> void:
	if notice_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_NOTICE_SFX_PATH):
		notice_sfx = load(DEFAULT_NOTICE_SFX_PATH) as AudioStream


func _get_current_messages_count() -> int:
	return _get_messages_for_channel(_current_channel).size()


func _get_messages_for_channel(channel: int) -> Array[String]:
	if channel == LogChannel.DEBUG:
		return _debug_messages
	return _normal_messages


func _to_packed_string_array(messages: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for message in messages:
		result.append(message)
	return result


func _get_card_text_color(channel: int) -> Color:
	if channel == LogChannel.DEBUG:
		return debug_card_text_color
	return card_text_color


func _make_card_style(channel: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if channel == LogChannel.DEBUG:
		style.bg_color = debug_card_background_color
		style.border_color = debug_card_border_color
	else:
		style.bg_color = card_background_color
		style.border_color = card_border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0.0)
	return style
