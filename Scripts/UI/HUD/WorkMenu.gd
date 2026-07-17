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

@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var job_001_button: Button = $MarginContainer/Rows/JobList/Job001Button
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _worker: Node
var _connected_worker: Node
var _is_work_processing: bool = false
var _pending_worker_ref: WeakRef


func _ready() -> void:
	visible = false
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	close_button.pressed.connect(close_menu)
	job_001_button.pressed.connect(_on_job_001_pressed)
	_resolve_worker()
	_connect_worker_signals()
	_refresh()


func _exit_tree() -> void:
	_disconnect_worker_signals()
	_pending_worker_ref = null


func open_menu() -> void:
	_apply_bottom_right_layout()
	visible = true
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


func set_worker_actor(worker: Node) -> bool:
	if worker != null and not is_instance_valid(worker):
		return false
	if _worker == worker:
		_connect_worker_signals()
		return true
	if is_work_processing():
		_pending_worker_ref = weakref(worker) if worker != null else null
		return false
	_pending_worker_ref = null
	_disconnect_worker_signals()
	_worker = worker
	worker_path = get_path_to(worker) if worker != null else NodePath("")
	_connect_worker_signals()
	if visible:
		_refresh()
	return true


func _refresh() -> void:
	var rank := _get_first_job_rank()
	var pay := _get_first_job_pay_for_rank(rank)
	job_001_button.text = "%s\n%s / %s / ランク %d / 給与 CR %d" % [
		first_job_name,
		first_job_category_name,
		_get_duration_text(),
		rank,
		pay,
	]
	job_001_button.disabled = false
	detail_label.text = "%s / %s: ボタンを押すと%sに状況を確認してから、エントランスへ出勤します。完了するとランクが上がります。MAX %d" % [
		first_job_name,
		first_job_category_name,
		_get_worker_display_name(),
		_get_max_job_rank(),
	]


func _on_job_001_pressed() -> void:
	var worker := _get_worker()
	if worker == null or not worker.has_method("request_work_at_entrance"):
		_show_work_request_rejected(work_unavailable_text)
		return

	if worker.call("request_work_at_entrance", first_job_id, first_job_name, first_job_minutes) == true:
		_set_work_processing(true)
		_push_message("%sへ向かいます。" % first_job_name)
		close_menu()
		return

	_set_work_processing(false)
	_show_work_request_rejected(_get_worker_work_unavailable_message(worker))


func _show_work_request_rejected(message: String) -> void:
	var safe_message := message.strip_edges()
	if safe_message.is_empty():
		safe_message = work_unavailable_text
	detail_label.text = safe_message
	_push_message(safe_message)


func _get_worker_work_unavailable_message(worker: Node) -> String:
	if worker == null:
		return work_unavailable_text
	if worker.has_method("is_sleeping") and worker.call("is_sleeping") == true:
		return sleeping_detail_text
	if worker.has_method("is_working") and worker.call("is_working") == true:
		return working_detail_text
	if worker.has_method("get_current_action_display_text"):
		var action_text := String(worker.call("get_current_action_display_text")).strip_edges()
		if not action_text.is_empty():
			return "今は%sなので、仕事には行けません。" % action_text
	return work_unavailable_text


func _set_work_processing(work_processing: bool) -> void:
	_is_work_processing = work_processing
	_notify_movement_lock_controller()
	if visible:
		_refresh()


func _notify_movement_lock_controller() -> void:
	get_tree().call_group(MOVEMENT_LOCK_CONTROLLER_GROUP, "refresh_movement_button_locks")


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
	_disconnect_worker_signals()
	_connected_worker = _worker
	var callable := Callable(self, "_on_worker_work_completed")
	if _connected_worker.has_signal(&"work_completed") and not _connected_worker.is_connected(&"work_completed", callable):
		_connected_worker.connect(&"work_completed", callable)


func _disconnect_worker_signals() -> void:
	if _connected_worker != null and is_instance_valid(_connected_worker):
		var callable := Callable(self, "_on_worker_work_completed")
		if _connected_worker.has_signal(&"work_completed") and _connected_worker.is_connected(&"work_completed", callable):
			_connected_worker.disconnect(&"work_completed", callable)
	_connected_worker = null


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
	_apply_pending_worker_change()
	if visible:
		_refresh()


func _apply_pending_worker_change() -> void:
	if _pending_worker_ref == null:
		return
	var pending_ref := _pending_worker_ref
	_pending_worker_ref = null
	var pending_worker := pending_ref.get_ref() as Node
	if pending_worker == null or not is_instance_valid(pending_worker):
		return
	set_worker_actor(pending_worker)


func _get_worker_display_name() -> String:
	var worker := _get_worker()
	if worker == null:
		return "キャラクター"
	var display_name_value: Variant = worker.get("display_name")
	if display_name_value != null and not String(display_name_value).strip_edges().is_empty():
		return String(display_name_value)
	return worker.name


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
