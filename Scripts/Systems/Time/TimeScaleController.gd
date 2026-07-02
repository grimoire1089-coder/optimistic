extends Node
class_name TimeScaleControllerSystem

signal time_scale_changed(new_scale: float, reason: String)
signal sleep_fast_forward_changed(enabled: bool)

const NORMAL_SCALE: float = 1.0
const SLEEP_FAST_SCALE: float = 8.0

var current_reason: String = "normal"
var is_sleep_fast_forward: bool = false

var _scale_requests: Dictionary = {}


func _ready() -> void:
	add_to_group("time_scale_controller")
	reset_time_scale()


func _exit_tree() -> void:
	Engine.time_scale = NORMAL_SCALE


func set_sleep_fast_forward(enabled: bool) -> void:
	set_time_scale_request("sleep_fast_forward", enabled, SLEEP_FAST_SCALE)

	if is_sleep_fast_forward == enabled:
		return

	is_sleep_fast_forward = enabled
	sleep_fast_forward_changed.emit(enabled)


func set_time_scale_request(reason: String, enabled: bool, scale: float) -> void:
	if reason.is_empty():
		return

	if enabled:
		_scale_requests[reason] = maxf(scale, NORMAL_SCALE)
	else:
		_scale_requests.erase(reason)

	_apply_highest_request()


func clear_time_scale_request(reason: String) -> void:
	set_time_scale_request(reason, false, NORMAL_SCALE)


func reset_time_scale() -> void:
	_scale_requests.clear()
	is_sleep_fast_forward = false
	_set_engine_time_scale(NORMAL_SCALE, "normal")


func update_sleep_fast_forward(map_ai_count: int, sleeping_ai_count: int, can_fast_forward: bool = true) -> void:
	var should_fast_forward: bool = can_fast_forward and map_ai_count == 1 and sleeping_ai_count == 1
	set_sleep_fast_forward(should_fast_forward)


func is_fast_forwarding() -> bool:
	return not is_equal_approx(Engine.time_scale, NORMAL_SCALE)


func get_current_scale() -> float:
	return Engine.time_scale


func _apply_highest_request() -> void:
	var next_reason: String = "normal"
	var next_scale: float = NORMAL_SCALE

	for reason in _scale_requests.keys():
		var scale: float = float(_scale_requests[reason])
		if scale > next_scale:
			next_scale = scale
			next_reason = str(reason)

	_set_engine_time_scale(next_scale, next_reason)


func _set_engine_time_scale(scale: float, reason: String) -> void:
	var safe_scale: float = maxf(scale, NORMAL_SCALE)

	if is_equal_approx(Engine.time_scale, safe_scale) and current_reason == reason:
		return

	Engine.time_scale = safe_scale
	current_reason = reason
	time_scale_changed.emit(safe_scale, reason)
