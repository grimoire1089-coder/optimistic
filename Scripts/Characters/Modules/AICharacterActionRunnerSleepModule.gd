extends AICharacterSleepBehaviorModule
class_name AICharacterActionRunnerSleepModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

@export var action_runner_integration_enabled: bool = false
@export var action_runner_ai_actor_group_name: StringName = &"ai_character_actor"
@export var action_runner_use_shared_move_slot: bool = true

var _action_runner_controlled := false
var _sleep_need_signal_source: CharacterNeedsModule
var _sleep_need_was_requested := false
var _floor_sleep_was_requested := false


func setup(body: CharacterBody2D) -> void:
	_disconnect_sleep_need_signal()
	super.setup(body)
	_connect_sleep_need_signal()
	_sync_sleep_request_state()


func _exit_tree() -> void:
	_disconnect_sleep_need_signal()
	cancel_action_runner_sleep()


func can_start_action_runner_sleep() -> bool:
	if not action_runner_integration_enabled:
		return false
	_resolve_refs()
	if _body == null or not is_instance_valid(_body) or _needs_module == null:
		return false
	if _action_runner_controlled or _is_active or _is_sleeping:
		return true
	if not _should_sleep_now():
		_clear_bedding_target()
		return false
	if _should_floor_sleep_now():
		return true
	if _has_valid_bedding_target():
		return true
	return _ensure_bedding_target()


func get_action_runner_sleep_score() -> float:
	if _is_sleeping or _is_active:
		return 2000.0
	if _should_floor_sleep_now():
		return 1800.0
	if _should_sleep_now():
		return 1000.0
	return -INF


func start_action_runner_sleep() -> bool:
	if not can_start_action_runner_sleep():
		return false
	_action_runner_controlled = true
	return true


func tick_action_runner_sleep(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		return AICharacterActionResult.completed("sleep action finished")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_sleep() -> void:
	_stop_sleeping()
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func cleanup_action_runner_sleep() -> void:
	if _action_runner_controlled or _is_active or _is_sleeping:
		_stop_sleeping()
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func get_action_runner_sleep_debug_summary() -> String:
	return "sleep runner_controlled=%s sleeping=%s floor=%s requested=%s emergency=%s %s" % [
		str(_action_runner_controlled),
		str(_is_sleeping),
		str(_is_floor_sleeping),
		str(_is_sleep_need_requested()),
		str(_is_floor_sleep_requested()),
		get_debug_movement_summary(),
	]


func _connect_sleep_need_signal() -> void:
	if _needs_module == null:
		return
	var callable := Callable(self, "_on_sleep_need_changed")
	if not _needs_module.need_changed.is_connected(callable):
		_needs_module.need_changed.connect(callable)
	_sleep_need_signal_source = _needs_module


func _disconnect_sleep_need_signal() -> void:
	if _sleep_need_signal_source == null or not is_instance_valid(_sleep_need_signal_source):
		_sleep_need_signal_source = null
		return
	var callable := Callable(self, "_on_sleep_need_changed")
	if _sleep_need_signal_source.need_changed.is_connected(callable):
		_sleep_need_signal_source.need_changed.disconnect(callable)
	_sleep_need_signal_source = null


func _on_sleep_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	if need_id != sleep_need_id:
		return
	var sleep_requested := _is_sleep_need_requested()
	var floor_sleep_requested := _is_floor_sleep_requested()
	var became_sleep_requested := sleep_requested and not _sleep_need_was_requested
	var became_floor_sleep_requested := floor_sleep_requested and not _floor_sleep_was_requested
	_sleep_need_was_requested = sleep_requested
	_floor_sleep_was_requested = floor_sleep_requested
	if not action_runner_integration_enabled:
		return
	if not became_sleep_requested and not became_floor_sleep_requested:
		return
	var runner := _get_action_runner()
	if runner == null or runner.get_active_action_id() == sleep_action_id:
		return
	var reason := "energy became critical" if became_floor_sleep_requested else "energy became low"
	runner.request_rethink(reason)


func _sync_sleep_request_state() -> void:
	_sleep_need_was_requested = _is_sleep_need_requested()
	_floor_sleep_was_requested = _is_floor_sleep_requested()


func _is_sleep_need_requested() -> bool:
	if _needs_module == null:
		return false
	return _get_energy_ratio() <= sleep_request_energy_ratio


func _is_floor_sleep_requested() -> bool:
	if _needs_module == null:
		return false
	return _get_energy_ratio() <= floor_sleep_energy_ratio


func _get_action_runner() -> AICharacterActionRunner:
	if _body == null or not is_instance_valid(_body):
		return null
	if not _body.has_method("get_ai_action_runner"):
		return null
	return _body.call("get_ai_action_runner") as AICharacterActionRunner


func _can_action_runner_move_now() -> bool:
	if _body == null:
		return false
	if not action_runner_use_shared_move_slot:
		return true
	if MoveSlot.can_move(_body):
		return MoveSlot.request_move(_body)
	if MoveSlot.is_other_actor_moving(_body, action_runner_ai_actor_group_name):
		return false
	return MoveSlot.request_move(_body)


func _release_action_runner_move_slot() -> void:
	if _body == null or not action_runner_use_shared_move_slot:
		return
	MoveSlot.release_move(_body)
