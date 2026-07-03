extends PanelContainer
class_name MessageLogPanel

const DEFAULT_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_001.ogg"

## TXT出力先。Godotのユーザーデータフォルダ内に保存する。
## Windowsなら概ね %APPDATA%/Godot/app_userdata/<project>/debug_logs/ に入る。
const DEBUG_LOG_EXPORT_DIRECTORY := "user://debug_logs"
const DEBUG_LOG_EXPORT_PREFIX := "debug_log"

enum LogChannel { NORMAL, DEBUG }

@export_range(1, 300, 1) var max_messages: int = 100
@export var notice_sfx: AudioStream
@export var notice_sfx_volume_db: float = 0.0
@export var auto_scroll_to_latest: bool = true
## 旧設定との互換用。デバッグログはコード側で常に無音にする。
@export var play_notice_sfx_for_debug: bool = false
@export_range(0.0, 10.0, 0.1) var queued_message_delay_seconds: float = 2.0
@export var card_height: float = 72.0
@export var card_horizontal_inset: float = 4.0
@export_range(8, 64, 1) var card_estimated_chars_per_line: int = 22
@export var card_estimated_line_height: float = 21.0
@export var card_estimated_vertical_padding: float = 30.0
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
@onready var export_debug_button: Button = %ExportDebugLogButton
@onready var tab_bar: TabBar = %LogTabBar
@onready var empty_label: Label = %EmptyLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var message_list: VBoxContainer = %MessageList

var _normal_messages: Array[String] = []
var _debug_messages: Array[String] = []
var _queued_normal_messages: Array[Dictionary] = []
var _queued_debug_messages: Array[Dictionary] = []
var _current_channel: int = LogChannel.NORMAL
var _is_processing_normal_queue: bool = false
var _is_processing_debug_queue: bool = false
var _last_exported_debug_log_path: String = ""


func _ready() -> void:
	add_to_group(&"message_log")
	_load_default_notice_sfx_if_needed()
	_setup_tabs()
	_connect_export_debug_button()
	_apply_bottom_stack_layout()
	_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()
	_update_export_debug_button()


func add_message(message: String) -> void:
	_queue_message_to_channel(message, LogChannel.NORMAL, true)


func add_debug_message(message: String) -> void:
	_add_message_to_channel_immediate(message, LogChannel.DEBUG, false)


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
	_queued_normal_messages.clear()
	_normal_messages.clear()
	if _current_channel == LogChannel.NORMAL:
		_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()
	_update_export_debug_button()


func clear_debug_messages() -> void:
	_queued_debug_messages.clear()
	_debug_messages.clear()
	if _current_channel == LogChannel.DEBUG:
		_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()
	_update_export_debug_button()


func clear_all_messages() -> void:
	_queued_normal_messages.clear()
	_queued_debug_messages.clear()
	_normal_messages.clear()
	_debug_messages.clear()
	_rebuild_visible_messages(false)
	_update_header()
	_update_empty_state()
	_update_export_debug_button()


func get_messages() -> PackedStringArray:
	return _to_packed_string_array(_normal_messages)


func get_debug_messages() -> PackedStringArray:
	return _to_packed_string_array(_debug_messages)


func switch_to_normal_log() -> void:
	_set_current_channel(LogChannel.NORMAL)


func switch_to_debug_log() -> void:
	_set_current_channel(LogChannel.DEBUG)


func get_last_exported_debug_log_path() -> String:
	return _last_exported_debug_log_path


func export_debug_log_to_txt() -> String:
	var file_path: String = _make_debug_log_file_path()
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(DEBUG_LOG_EXPORT_DIRECTORY)
	if make_dir_error != OK:
		add_debug_message("デバッグログ出力フォルダを作成できませんでした: %s" % error_string(make_dir_error))
		return ""

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		add_debug_message("デバッグログTXTを作成できませんでした: %s" % error_string(open_error))
		return ""

	file.store_string(_build_debug_log_export_text())
	file.close()

	_last_exported_debug_log_path = file_path
	add_debug_message("デバッグログTXTを出力しました: %s" % ProjectSettings.globalize_path(file_path))
	_update_export_debug_button()
	return file_path


func _on_export_debug_log_button_pressed() -> void:
	export_debug_log_to_txt()


func _queue_message_to_channel(message: String, channel: int, should_play_sfx: bool) -> void:
	var trimmed_message := message.strip_edges()
	if trimmed_message.is_empty():
		return

	if channel == LogChannel.DEBUG:
		should_play_sfx = false

	var queue := _get_queued_messages_for_channel(channel)
	queue.append({
		"message": trimmed_message,
		"should_play_sfx": should_play_sfx,
	})

	_start_queue_processor(channel)


func _start_queue_processor(channel: int) -> void:
	if _is_processing_queue(channel):
		return

	_set_processing_queue(channel, true)
	call_deferred("_process_message_queue", channel)


func _process_message_queue(channel: int) -> void:
	while is_inside_tree() and not _get_queued_messages_for_channel(channel).is_empty():
		var queue := _get_queued_messages_for_channel(channel)
		var entry: Dictionary = queue.pop_front()
		_add_message_to_channel_immediate(
			str(entry.get("message", "")),
			channel,
			bool(entry.get("should_play_sfx", false))
		)

		if not _get_queued_messages_for_channel(channel).is_empty() and queued_message_delay_seconds > 0.0:
			await get_tree().create_timer(queued_message_delay_seconds).timeout

	_set_processing_queue(channel, false)

	if is_inside_tree() and not _get_queued_messages_for_channel(channel).is_empty():
		_start_queue_processor(channel)


func _add_message_to_channel_immediate(message: String, channel: int, should_play_sfx: bool) -> void:
	var trimmed_message := message.strip_edges()
	if trimmed_message.is_empty():
		return

	if channel == LogChannel.DEBUG:
		should_play_sfx = false

	var messages := _get_messages_for_channel(channel)
	messages.append(trimmed_message)

	if channel == _current_channel:
		_create_message_card(trimmed_message, channel, true)

	_trim_old_messages(channel)
	_update_header()
	_update_empty_state()
	_update_export_debug_button()

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


func _connect_export_debug_button() -> void:
	if export_debug_button == null:
		return
	if not export_debug_button.pressed.is_connected(_on_export_debug_log_button_pressed):
		export_debug_button.pressed.connect(_on_export_debug_log_button_pressed)


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
	_update_export_debug_button()
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
	var target_card_height := _get_message_card_height(message)
	var holder := Control.new()
	holder.clip_contents = true
	holder.custom_minimum_size = Vector2(0.0, 0.0 if animate_card else target_card_height)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card := _make_card_node(message, channel, animate_card, target_card_height)
	holder.add_child(card)
	message_list.add_child(holder)

	if animate_card:
		call_deferred("_animate_message_card", holder, card, target_card_height)


func _make_card_node(message: String, channel: int, animate_card: bool, target_card_height: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, target_card_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.anchor_left = 0.0
	card.anchor_top = 1.0
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = card_horizontal_inset
	card.offset_right = -card_horizontal_inset
	if animate_card:
		card.offset_top = -target_card_height + card_enter_offset_y
		card.offset_bottom = card_enter_offset_y
		card.modulate.a = 0.0
	else:
		card.offset_top = -target_card_height
		card.offset_bottom = 0.0
		card.modulate.a = 1.0
	card.add_theme_stylebox_override("panel", _make_card_style(channel))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _get_card_text_color(channel))
	label.add_theme_font_size_override("font_size", 15)
	margin.add_child(label)

	return card


func _get_message_card_height(message: String) -> float:
	var estimated_line_count := 0
	var safe_chars_per_line := maxi(card_estimated_chars_per_line, 1)
	var text_lines := message.split("\n", false)

	if text_lines.is_empty():
		estimated_line_count = 1
	else:
		for text_line in text_lines:
			var line_length: int = maxi(text_line.length(), 1)
			estimated_line_count += maxi(int(ceilf(float(line_length) / float(safe_chars_per_line))), 1)

	var estimated_height := card_estimated_vertical_padding + float(estimated_line_count) * card_estimated_line_height
	return maxf(card_height, estimated_height)


func _animate_message_card(holder: Control, card: PanelContainer, target_card_height: float) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(card):
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "custom_minimum_size:y", target_card_height, card_enter_duration)
	tween.tween_property(card, "offset_top", -target_card_height, card_enter_duration)
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


func _update_export_debug_button() -> void:
	if export_debug_button == null:
		return
	var is_debug_channel: bool = _current_channel == LogChannel.DEBUG
	export_debug_button.visible = is_debug_channel
	export_debug_button.disabled = _debug_messages.is_empty() and _queued_debug_messages.is_empty()


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


func _get_queued_messages_for_channel(channel: int) -> Array[Dictionary]:
	if channel == LogChannel.DEBUG:
		return _queued_debug_messages
	return _queued_normal_messages


func _is_processing_queue(channel: int) -> bool:
	if channel == LogChannel.DEBUG:
		return _is_processing_debug_queue
	return _is_processing_normal_queue


func _set_processing_queue(channel: int, processing: bool) -> void:
	if channel == LogChannel.DEBUG:
		_is_processing_debug_queue = processing
		return
	_is_processing_normal_queue = processing


func _build_debug_log_export_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Optimistic Debug Log")
	lines.append("exported_at=%s" % _make_timestamp_text())
	lines.append("message_count=%d" % _debug_messages.size())
	if not _last_exported_debug_log_path.is_empty():
		lines.append("previous_export=%s" % ProjectSettings.globalize_path(_last_exported_debug_log_path))
	lines.append("---")
	for index in range(_debug_messages.size()):
		lines.append("%03d: %s" % [index + 1, _debug_messages[index]])
	return "\n".join(lines) + "\n"


func _make_debug_log_file_path() -> String:
	return "%s/%s_%s.txt" % [DEBUG_LOG_EXPORT_DIRECTORY, DEBUG_LOG_EXPORT_PREFIX, _make_file_timestamp_text()]


func _make_file_timestamp_text() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(stamp.get("year", 0)),
		int(stamp.get("month", 0)),
		int(stamp.get("day", 0)),
		int(stamp.get("hour", 0)),
		int(stamp.get("minute", 0)),
		int(stamp.get("second", 0)),
	]


func _make_timestamp_text() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(stamp.get("year", 0)),
		int(stamp.get("month", 0)),
		int(stamp.get("day", 0)),
		int(stamp.get("hour", 0)),
		int(stamp.get("minute", 0)),
		int(stamp.get("second", 0)),
	]


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
