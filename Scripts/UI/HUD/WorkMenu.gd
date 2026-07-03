extends PanelContainer
class_name WorkMenu

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const BOTTOM_RIGHT_PANEL_SIZE := Vector2(356.0, 196.0)

@export var first_job_id: StringName = &"part_time_001"
@export var first_job_name: String = "仕事001"
@export var first_job_category_name: String = "アルバイト"
@export var first_job_minutes: int = 8 * 60
@export var worker_path: NodePath = NodePath("../../Robin")
@export var sleeping_detail_text: String = "睡眠中なので、今は仕事できません。"
@export var working_detail_text: String = "すでに仕事へ向かっているか勤務中です。"
@export var work_unavailable_text: String = "今は仕事に行けません。"

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var job_001_button: Button = $MarginContainer/Rows/JobList/Job001Button
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _refresh_timer: float = 0.0
var _worker: Node


func _ready() -> void:
	visible = false
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	close_button.pressed.connect(close_menu)
	job_001_button.pressed.connect(_on_job_001_pressed)
	_resolve_worker()
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.25
	_refresh()


func open_menu() -> void:
	_apply_bottom_right_layout()
	visible = true
	_refresh_timer = 0.0
	_refresh()


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _refresh() -> void:
	title_label.text = "仕事"
	job_001_button.text = "%s\n%s / %s" % [first_job_name, first_job_category_name, _get_duration_text()]
	var sleeping := _is_worker_sleeping()
	var working := _is_worker_working()
	job_001_button.disabled = sleeping or working
	if sleeping:
		detail_label.text = sleeping_detail_text
		return
	if working:
		detail_label.text = working_detail_text
		return
	detail_label.text = "%s / %s: エントランスから出勤します。" % [first_job_name, first_job_category_name]


func _on_job_001_pressed() -> void:
	if _is_worker_sleeping():
		_refresh()
		_push_message(sleeping_detail_text)
		return
	if _is_worker_working():
		_refresh()
		_push_message(working_detail_text)
		return

	var worker := _get_worker()
	if worker == null or not worker.has_method("request_work_at_entrance"):
		_refresh()
		_push_message(work_unavailable_text)
		return

	if worker.call("request_work_at_entrance", first_job_id, first_job_name, first_job_minutes) == true:
		_push_message("%sへ向かいます。" % first_job_name)
		close_menu()
		return

	_refresh()
	_push_message(work_unavailable_text)


func _is_worker_sleeping() -> bool:
	var worker := _get_worker()
	if worker == null:
		return false
	if not worker.has_method("is_sleeping"):
		return false
	return worker.call("is_sleeping") == true


func _is_worker_working() -> bool:
	var worker := _get_worker()
	if worker == null:
		return false
	if not worker.has_method("is_working"):
		return false
	return worker.call("is_working") == true


func _get_worker() -> Node:
	if _worker != null and is_instance_valid(_worker):
		return _worker
	_resolve_worker()
	return _worker


func _resolve_worker() -> void:
	_worker = null
	if worker_path.is_empty():
		return
	_worker = get_node_or_null(worker_path)


func _get_duration_text() -> String:
	if first_job_minutes % 60 == 0:
		return "%d時間" % int(first_job_minutes / 60.0)
	return "%d分" % first_job_minutes


func _apply_bottom_right_layout() -> void:
	custom_minimum_size = BOTTOM_RIGHT_PANEL_SIZE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -BOTTOM_RIGHT_MARGIN.x - BOTTOM_RIGHT_PANEL_SIZE.x
	offset_top = -BOTTOM_RIGHT_MARGIN.y - BOTTOM_RIGHT_PANEL_SIZE.y
	offset_right = -BOTTOM_RIGHT_MARGIN.x
	offset_bottom = -BOTTOM_RIGHT_MARGIN.y
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log") as MessageLogPanel
	if message_log == null:
		return
	message_log.add_message(message)