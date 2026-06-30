extends PanelContainer
class_name MessageLogPanel

const DEFAULT_NOTICE_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Notice_001.ogg"

@export_range(1, 300, 1) var max_messages: int = 100
@export var notice_sfx: AudioStream
@export var notice_sfx_volume_db: float = 0.0
@export var auto_scroll_to_latest: bool = true
@export var card_height: float = 58.0
@export var card_enter_offset_y: float = 18.0
@export var card_enter_duration: float = 0.22
@export var card_background_color: Color = Color(0.035, 0.04, 0.06, 0.96)
@export var card_border_color: Color = Color(0.14, 0.8, 0.95, 0.9)
@export var card_text_color: Color = Color(0.92, 0.98, 1.0, 1.0)

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var empty_label: Label = %EmptyLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var message_list: VBoxContainer = %MessageList

var _messages: Array[String] = []


func _ready() -> void:
	add_to_group(&"message_log")
	_load_default_notice_sfx_if_needed()
	_apply_bottom_stack_layout()
	_update_header()
	_update_empty_state()


func add_message(message: String) -> void:
	var trimmed_message := message.strip_edges()
	if trimmed_message.is_empty():
		return

	_messages.append(trimmed_message)
	_create_message_card(trimmed_message)
	_trim_old_messages()
	_update_header()
	_update_empty_state()
	_play_notice_sfx()

	if auto_scroll_to_latest:
		call_deferred("_scroll_to_latest")


func add_messages(messages: PackedStringArray) -> void:
	for message in messages:
		add_message(message)


func clear_messages() -> void:
	_messages.clear()
	for child in message_list.get_children():
		child.queue_free()
	_update_header()
	_update_empty_state()


func get_messages() -> PackedStringArray:
	var result := PackedStringArray()
	for message in _messages:
		result.append(message)
	return result


func _apply_bottom_stack_layout() -> void:
	if message_list == null:
		return
	message_list.alignment = BoxContainer.ALIGNMENT_END


func _create_message_card(message: String) -> void:
	var holder := Control.new()
	holder.clip_contents = true
	holder.custom_minimum_size = Vector2(0.0, 0.0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card := _make_card_node(message)
	holder.add_child(card)
	message_list.add_child(holder)

	call_deferred("_animate_message_card", holder, card)


func _make_card_node(message: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, card_height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.anchor_left = 0.0
	card.anchor_top = 1.0
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 0.0
	card.offset_top = -card_height + card_enter_offset_y
	card.offset_right = 0.0
	card.offset_bottom = card_enter_offset_y
	card.modulate.a = 0.0
	card.add_theme_stylebox_override("panel", _make_card_style())

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
	label.add_theme_color_override("font_color", card_text_color)
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


func _trim_old_messages() -> void:
	while _messages.size() > max_messages:
		_messages.pop_front()
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
		count_label.text = "%d/%d" % [_messages.size(), max_messages]


func _update_empty_state() -> void:
	var is_empty := _messages.is_empty()
	if empty_label != null:
		empty_label.visible = is_empty
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


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = card_background_color
	style.border_color = card_border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0.0)
	return style
