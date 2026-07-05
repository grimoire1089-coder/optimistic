extends PanelContainer
class_name CharacterMoodPanel

const MOOD_MAX_VALUE := 100
const BORDER_NOISE := 50
const BORDER_FRAIL := 35
const BORDER_BREAK := 20
const POSITIVE_POINT_COLOR := Color(0.30, 1.00, 0.42, 1.0)
const NEGATIVE_POINT_COLOR := Color(1.00, 0.28, 0.24, 1.0)
const NEUTRAL_POINT_COLOR := Color(0.82, 0.95, 1.00, 1.0)
const REMAINING_TIME_COLOR := Color(0.62, 0.88, 1.00, 1.0)

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _mood_module: CharacterMoodModule

func _ready() -> void:
	if _mood_module != null:
		_rebuild()

func set_mood_module(module: CharacterMoodModule) -> void:
	_disconnect_mood_module()
	_mood_module = module
	_connect_mood_module()
	if is_node_ready():
		_rebuild()

func set_character_needs(_needs: CharacterNeeds) -> void:
	set_mood_module(null)

func set_needs_module(_module: CharacterNeedsModule) -> void:
	set_mood_module(null)

func refresh() -> void:
	if is_node_ready():
		_rebuild()

func _connect_mood_module() -> void:
	if _mood_module == null:
		return
	var mood_callable := Callable(self, "_on_mood_changed")
	if not _mood_module.mood_changed.is_connected(mood_callable):
		_mood_module.mood_changed.connect(mood_callable)
	var entries_callable := Callable(self, "_on_entries_changed")
	if not _mood_module.entries_changed.is_connected(entries_callable):
		_mood_module.entries_changed.connect(entries_callable)

func _disconnect_mood_module() -> void:
	if _mood_module == null:
		return
	var mood_callable := Callable(self, "_on_mood_changed")
	if _mood_module.mood_changed.is_connected(mood_callable):
		_mood_module.mood_changed.disconnect(mood_callable)
	var entries_callable := Callable(self, "_on_entries_changed")
	if _mood_module.entries_changed.is_connected(entries_callable):
		_mood_module.entries_changed.disconnect(entries_callable)

func _rebuild() -> void:
	_clear_rows()
	if _rows == null:
		return
	_rows.add_theme_constant_override("separation", 8)
	if _mood_module == null:
		_add_message_row("ムードデータなし")
		return

	_add_summary_row()
	var entries := _mood_module.get_entries()
	if entries.is_empty():
		_add_message_row("現在の心情効果はありません")
		return

	for entry in entries:
		if entry == null:
			continue
		_add_entry_row(entry)

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()

func _add_summary_row() -> void:
	var value := _mood_module.get_mood_value()
	var total := _mood_module.get_total_points()
	var status := _get_decadence_mood_status(value)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 6)
	_rows.add_child(summary)

	var title := Label.new()
	title.text = "心情: %s   %d / 100   補正 %s" % [status, value, _get_signed_point_text(total)]
	title.add_theme_font_size_override("font_size", 15)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(title)

	var mood_bar := MoodScaleBar.new()
	mood_bar.custom_minimum_size = Vector2(0, 46)
	mood_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mood_bar.set_value(value)
	summary.add_child(mood_bar)

	var border_label := Label.new()
	border_label.text = "境界: 心相ノイズ %d / 感情回路摩耗 %d / コア崩落警戒 %d" % [BORDER_NOISE, BORDER_FRAIL, BORDER_BREAK]
	border_label.add_theme_font_size_override("font_size", 12)
	border_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(border_label)

func _add_message_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)

func _add_entry_row(entry: CharacterMoodEntryInstance) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(row)

	var detail_label := Label.new()
	detail_label.text = entry.get_detail_text()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.visible = false

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	row.add_child(header)

	var button := CheckButton.new()
	button.text = entry.get_display_name()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggled.connect(Callable(detail_label, "set_visible"))
	header.add_child(button)

	var point_label := Label.new()
	point_label.text = _get_signed_point_text(entry.get_point())
	point_label.custom_minimum_size = Vector2(44, 0)
	point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	point_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	point_label.add_theme_font_size_override("font_size", 14)
	point_label.add_theme_color_override("font_color", _get_point_color(entry.get_point()))
	header.add_child(point_label)

	var remaining_text := _get_remaining_time_text(entry)
	if not remaining_text.is_empty():
		var remaining_label := Label.new()
		remaining_label.text = remaining_text
		remaining_label.custom_minimum_size = Vector2(78, 0)
		remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		remaining_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		remaining_label.add_theme_font_size_override("font_size", 12)
		remaining_label.add_theme_color_override("font_color", REMAINING_TIME_COLOR)
		header.add_child(remaining_label)

	row.add_child(detail_label)

func _get_remaining_time_text(entry: CharacterMoodEntryInstance) -> String:
	if entry == null or not entry.has_time_limit():
		return ""
	if _mood_module == null:
		return ""
	var remaining_minutes := entry.get_remaining_game_minutes(_mood_module.get_current_absolute_minute())
	if remaining_minutes <= 0:
		return "残り 0分"
	var hours := remaining_minutes / 60
	var minutes := remaining_minutes % 60
	if hours > 0 and minutes > 0:
		return "残り %d時間%d分" % [hours, minutes]
	if hours > 0:
		return "残り %d時間" % hours
	return "残り %d分" % minutes

func _get_decadence_mood_status(value: int) -> String:
	if value < BORDER_BREAK:
		return "コア崩落警戒"
	if value < BORDER_FRAIL:
		return "感情回路摩耗"
	if value < BORDER_NOISE:
		return "心相ノイズ"
	return "ネオン安定"

func _get_signed_point_text(point: int) -> String:
	if point > 0:
		return "+%d" % point
	return str(point)

func _get_point_color(point: int) -> Color:
	if point > 0:
		return POSITIVE_POINT_COLOR
	if point < 0:
		return NEGATIVE_POINT_COLOR
	return NEUTRAL_POINT_COLOR

func _on_mood_changed(_old_value: int, _new_value: int) -> void:
	_rebuild()

func _on_entries_changed() -> void:
	_rebuild()


class MoodScaleBar extends Control:
	const MAX_VALUE := 100.0
	const NOISE_VALUE := 50.0
	const FRAIL_VALUE := 35.0
	const BREAK_VALUE := 20.0
	const BAR_HEIGHT := 18.0
	const TOP_PADDING := 12.0
	const MARKER_HEIGHT := 8.0

	var _value: int = 0

	func set_value(value: int) -> void:
		_value = clampi(value, 0, int(MAX_VALUE))
		queue_redraw()

	func _draw() -> void:
		var width := size.x
		if width <= 0.0:
			return
		var bar_rect := Rect2(Vector2(0, TOP_PADDING), Vector2(width, BAR_HEIGHT))
		draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.92), true)
		draw_rect(Rect2(bar_rect.position, Vector2(width * float(_value) / MAX_VALUE, BAR_HEIGHT)), Color(0.20, 0.78, 0.82, 1.0), true)
		_draw_border_line(NOISE_VALUE, Color(1.0, 0.94, 0.20, 1.0), bar_rect)
		_draw_border_line(FRAIL_VALUE, Color(1.0, 0.68, 0.15, 1.0), bar_rect)
		_draw_border_line(BREAK_VALUE, Color(1.0, 0.22, 0.18, 1.0), bar_rect)
		_draw_current_marker(bar_rect)

	func _draw_border_line(value: float, color: Color, bar_rect: Rect2) -> void:
		var x := bar_rect.position.x + bar_rect.size.x * value / MAX_VALUE
		draw_line(Vector2(x, bar_rect.position.y), Vector2(x, bar_rect.position.y + bar_rect.size.y), color, 2.0)

	func _draw_current_marker(bar_rect: Rect2) -> void:
		var x := bar_rect.position.x + bar_rect.size.x * float(_value) / MAX_VALUE
		var points := PackedVector2Array([
			Vector2(x, bar_rect.position.y - 2.0),
			Vector2(x - 7.0, bar_rect.position.y - MARKER_HEIGHT),
			Vector2(x + 7.0, bar_rect.position.y - MARKER_HEIGHT),
		])
		draw_polygon(points, PackedColorArray([Color(1.0, 0.30, 0.22, 1.0)]))
