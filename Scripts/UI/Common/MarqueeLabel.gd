extends Control
class_name MarqueeLabel

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

@export_range(8, 48, 1) var font_size: int = 13:
	set(value):
		font_size = value
		_apply_font_size()

@export_range(4.0, 240.0, 1.0) var scroll_speed: float = 28.0
@export_range(0.0, 4.0, 0.1) var edge_wait_seconds: float = 0.8
@export_range(8.0, 128.0, 1.0) var restart_gap: float = 32.0

var _label: Label
var _scroll_offset: float = 0.0
var _wait_timer: float = 0.0


func _ready() -> void:
	clip_contents = true
	_ensure_label()
	_apply_text()
	_apply_font_size()
	resized.connect(_reset_scroll)
	set_process(true)


func set_display_text(value: String) -> void:
	text = value


func _process(delta: float) -> void:
	if _label == null:
		return

	var available_width := size.x
	var label_width := _label.get_combined_minimum_size().x
	if label_width <= available_width:
		_label.position.x = max((available_width - label_width) * 0.5, 0.0)
		_scroll_offset = 0.0
		_wait_timer = 0.0
		return

	if _wait_timer > 0.0:
		_wait_timer = max(_wait_timer - delta, 0.0)
		return

	_scroll_offset += scroll_speed * delta
	var limit := label_width - available_width + restart_gap
	if _scroll_offset >= limit:
		_scroll_offset = 0.0
		_wait_timer = edge_wait_seconds

	_label.position.x = -_scroll_offset


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = "TextLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.clip_text = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func _apply_text() -> void:
	_ensure_label()
	_label.text = text
	_reset_scroll()


func _apply_font_size() -> void:
	_ensure_label()
	_label.add_theme_font_size_override("font_size", font_size)
	_reset_scroll()


func _reset_scroll() -> void:
	_scroll_offset = 0.0
	_wait_timer = edge_wait_seconds
	if _label != null:
		_label.position.x = 0.0
