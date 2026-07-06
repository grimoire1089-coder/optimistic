extends PanelContainer
class_name WorkMenu

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const BOTTOM_RIGHT_PANEL_SIZE := Vector2(356.0, 196.0)
const MOVEMENT_LOCK_CONTROLLER_GROUP: StringName = &"hud_movement_lock_controller"

@export var first_job_id: StringName = &"part_time_001"
@export var first_job_name: String = "仕事001"
@export var first_job_category_name: String = "アルバイト"
@export var first_job_minutes: int = 8 * 60
@export var first_job_base_pay: int = 500
@export var first_job_rank_pay_bonus: int = 75
@export var first_job_rank_gain_on_complete: int = 1
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
var _connected_worker: Node
var _is_work_processing: bool = false


func _ready() -> void:
	visible = false
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	close_button.pressed.connect(close_menu)
	job_001_button.pressed.connect(_on_job_001_pressed)
	_resolve_worker()
	_connect_worker_signals()
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


func is_work_processing() -> bool:
	return _is_work_processing or _is_worker_working()


func _refresh() -> void:
	title_label.text = "仕事"
	var rank := _get_first_job_rank()
	var pay := _get_first_job_pay_for_rank(rank)
	job_001_button.text = "%s\n%s / %s / ランク %d / 給与 CR %d" % [
		first_job_name,
		first_job_category_name,
		_get_duration_text(),
		rank,
		pay,
	]
	var sleeping := _is_worker_sleeping()
	var working := is_work_processing()
	job_001_button.disabled = sleeping or working
	if sleeping:
		detail_label.text = sleeping_detail_text
		return
	if working:
		detail_label.text = working_detail_text
		return
	detail_label.text = "%s / %s: エントランスから出勤します。完了するとランクが上がります。MAX %d" % [
		first_job_name,
		first_job_category_name,
		_get_max_job_rank(),
	]


func _on_job_001_pressed() -> void:
	if _is_worker_sleeping():
		_refresh()
		_push_message(sleeping_detail_text)
		return
	if is_work_processing():
		_refresh()
		_push_message(working_detail_text)
		return

	var worker := _get_worker()
	if worker == null or not worker.has_method("request_work_at_entrance"):
		_refresh()
		_push_message(work_unavailable_text)
		return

	if worker.call("request_work_at_entrance", first_job_id, first_job_name, first_job_minutes) == true:
		_set_work_processing(true)
		_push_message("%sへ向かいます。" % first_job_name)
		close_menu()
		return

	_set_work_processing(false)
	_refresh()
	_push_message(work_unavailable_text)


func _set_work_processing(work_processing: bool) -> void:
	_is_work_processing = work_processing
	_notify_movement_lock_controller()
	if visible:
		_refresh()


func _notify_movement_lock_controller() -> void:
	get_tree().call_group(MOVEMENT_LOCK_CONTROLLER_GROUP, "refresh_movement_button_locks")


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
		_connect_worker_signals()
		return _worker
	_resolve_worker()
	_connect_worker_signals()
	return _worker


func _resolve_worker() -> void:
	_worker = null
	if worker_path.is_empty():
		return
	_worker = get_node_or_null(worker_path)
	_connect_worker_signals()


func _connect_worker_signals() -> void:
	if _worker == null or not is_instance_valid(_worker):
		return
	if _connected_worker == _worker:
		return
	if _connected_worker != null and is_instance_valid(_connected_worker):
		var old_callable := Callable(self, "_on_worker_work_completed")
		if _connected_worker.has_signal(&"work_completed") and _connected_worker.is_connected(&"work_completed", old_callable):
			_connected_worker.disconnect(&"work_completed", old_callable)
	_connected_worker = _worker
	var callable := Callable(self, "_on_worker_work_completed")
	if _connected_worker.has_signal(&"work_completed") and not _connected_worker.is_connected(&"work_completed", callable):
		_connected_worker.connect(&"work_completed", callable)


func _on_worker_work_completed(job_id: StringName) -> void:
	if job_id != first_job_id:
		return
	_set_work_processing(false)
	var previous_rank := _get_first_job_rank()
	var pay := _get_first_job_pay_for_rank(previous_rank)
	_add_work_pay(pay, "work_%s_rank_%d" % [String(job_id), previous_rank])

	var result := _record_first_job_completed()
	var next_rank := int(result.get("rank", previous_rank))
	var rank_changed := bool(result.get("rank_changed", false))
	if rank_changed:
		_push_message("%sを完了しました。給与 CR %d を受け取りました。ランク %d → %d" % [
			first_job_name,
			pay,
			previous_rank,
			next_rank,
		])
	else:
		_push_message("%sを完了しました。給与 CR %d を受け取りました。ランク %d / MAX %d" % [
			first_job_name,
			pay,
			next_rank,
			_get_max_job_rank(),
		])
	_refresh()


func _get_first_job_rank() -> int:
	var rank_system := _get_work_rank_system()
	if rank_system == null or not rank_system.has_method("get_job_rank"):
		return 1
	return int(rank_system.call("get_job_rank", first_job_id))


func _get_first_job_pay_for_rank(rank: int) -> int:
	var safe_rank := clampi(rank, 1, _get_max_job_rank())
	return maxi(first_job_base_pay + (safe_rank - 1) * first_job_rank_pay_bonus, 0)


func _record_first_job_completed() -> Dictionary:
	var rank_system := _get_work_rank_system()
	if rank_system == null or not rank_system.has_method("record_job_completed"):
		return {
			"previous_rank": _get_first_job_rank(),
			"rank": _get_first_job_rank(),
			"rank_changed": false,
		}
	var result_value: Variant = rank_system.call("record_job_completed", first_job_id, first_job_rank_gain_on_complete)
	if result_value is Dictionary:
		var result: Dictionary = result_value
		return result
	return {}


func _get_max_job_rank() -> int:
	var rank_system := _get_work_rank_system()
	if rank_system == null or not rank_system.has_method("get_max_rank"):
		return 10
	return int(rank_system.call("get_max_rank"))


func _get_work_rank_system() -> Node:
	return get_node_or_null("/root/WorkRankSystem")


func _add_work_pay(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var wallet := get_node_or_null("/root/CreditWallet")
	if wallet == null or not wallet.has_method("add"):
		push_warning("WorkMenu: CreditWallet が見つからないため、給与を加算できません。")
		return
	wallet.call("add", amount, reason)


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
