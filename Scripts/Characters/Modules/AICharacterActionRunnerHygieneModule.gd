extends AICharacterHygieneBehaviorModule
class_name AICharacterActionRunnerHygieneModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

const BUILD_LOCK_META := &"build_locked_by_sleep"
const BUILD_LOCK_REASON_META := &"build_lock_reason"
const SHOWER_BUILD_LOCK_OWNER_META := &"ai_hygiene_build_lock_owner"
const SHOWER_RESERVED_BY_META := &"ai_hygiene_reserved_by"
const SHOWER_RESERVED_NAME_META := &"ai_hygiene_reserved_name"
const SHOWER_RESERVED_REASON_META := &"ai_hygiene_reserved_reason"
const SHOWER_LOCK_REASON := "シャワー使用中"

@export var action_runner_integration_enabled: bool = false
@export var action_runner_ai_actor_group_name: StringName = &"ai_character_actor"
@export var action_runner_use_shared_move_slot: bool = true

var _action_runner_controlled := false
var _hygiene_need_signal_source: CharacterNeedsModule
var _layout_signal_source: Node
var _hygiene_need_was_requested := false
var _locked_shower: Node2D


func setup(body: CharacterBody2D) -> void:
	_disconnect_hygiene_need_signal()
	_disconnect_layout_signal()
	super.setup(body)
	_connect_hygiene_need_signal()
	_connect_layout_signal()
	_hygiene_need_was_requested = _is_hygiene_need_requested()


func _exit_tree() -> void:
	_disconnect_hygiene_need_signal()
	_disconnect_layout_signal()
	cancel_action_runner_hygiene()


func can_start_action_runner_hygiene() -> bool:
	if not action_runner_integration_enabled:
		return false
	_resolve_refs()
	if _body == null or not is_instance_valid(_body) or _needs_module == null:
		return false
	if _has_action_runner_hygiene_commitment():
		return true
	if _cooldown_timer > 0.0:
		return false
	if not _should_maintain_hygiene_now():
		_clear_hygiene_target()
		return false
	if _has_valid_hygiene_target():
		_claim_current_shower()
		return true
	return _ensure_hygiene_target()


func get_action_runner_hygiene_score() -> float:
	if _is_showering or _is_active:
		return 700.0
	if _is_hygiene_need_requested():
		return 300.0
	if _should_maintain_hygiene_now():
		return 250.0
	return -INF


func start_action_runner_hygiene() -> bool:
	if not can_start_action_runner_hygiene():
		return false
	_action_runner_controlled = true
	_claim_current_shower()
	return true


func tick_action_runner_hygiene(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		return AICharacterActionResult.completed("hygiene action finished")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_hygiene() -> void:
	_reset_action_runner_hygiene_state()
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func cleanup_action_runner_hygiene() -> void:
	if _has_action_runner_hygiene_commitment():
		_reset_action_runner_hygiene_state()
	_cooldown_timer = 0.0
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func get_action_runner_hygiene_debug_summary() -> String:
	return "hygiene runner_controlled=%s showering=%s requested=%s reserved=%s locked=%s %s" % [
		str(_action_runner_controlled),
		str(_is_showering),
		str(_is_hygiene_need_requested()),
		str(_target_shower != null),
		str(_locked_shower != null),
		get_debug_movement_summary(),
	]


func _has_action_runner_hygiene_commitment() -> bool:
	return (
		_action_runner_controlled
		or _is_active
		or _is_showering
		or _target_shower != null
		or _locked_shower != null
	)


func _reset_action_runner_hygiene_state() -> void:
	_is_showering = false
	_shower_timer = 0.0
	_shower_start_progress = 0.0
	_action_progress_ratio = 0.0
	_finish_hygiene_action()
	_cooldown_timer = 0.0


func _connect_hygiene_need_signal() -> void:
	if _needs_module == null:
		return
	var callable := Callable(self, "_on_hygiene_need_changed")
	if not _needs_module.need_changed.is_connected(callable):
		_needs_module.need_changed.connect(callable)
	_hygiene_need_signal_source = _needs_module


func _disconnect_hygiene_need_signal() -> void:
	if _hygiene_need_signal_source == null or not is_instance_valid(_hygiene_need_signal_source):
		_hygiene_need_signal_source = null
		return
	var callable := Callable(self, "_on_hygiene_need_changed")
	if _hygiene_need_signal_source.need_changed.is_connected(callable):
		_hygiene_need_signal_source.need_changed.disconnect(callable)
	_hygiene_need_signal_source = null


func _connect_layout_signal() -> void:
	if _furniture_placement_module == null or not _furniture_placement_module.has_signal(&"layout_changed"):
		return
	var callable := Callable(self, "_on_furniture_layout_changed")
	if not _furniture_placement_module.is_connected(&"layout_changed", callable):
		_furniture_placement_module.connect(&"layout_changed", callable)
	_layout_signal_source = _furniture_placement_module


func _disconnect_layout_signal() -> void:
	if _layout_signal_source == null or not is_instance_valid(_layout_signal_source):
		_layout_signal_source = null
		return
	var callable := Callable(self, "_on_furniture_layout_changed")
	if _layout_signal_source.is_connected(&"layout_changed", callable):
		_layout_signal_source.disconnect(&"layout_changed", callable)
	_layout_signal_source = null


func _on_hygiene_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	if need_id != hygiene_need_id:
		return
	var hygiene_requested := _is_hygiene_need_requested()
	var became_requested := hygiene_requested and not _hygiene_need_was_requested
	_hygiene_need_was_requested = hygiene_requested
	if not became_requested or not action_runner_integration_enabled:
		return
	_request_action_runner_rethink("hygiene need became actionable")


func _on_furniture_layout_changed(_layout_version: int) -> void:
	if not action_runner_integration_enabled or not _is_hygiene_need_requested():
		return
	if _has_action_runner_hygiene_commitment():
		return
	_request_action_runner_rethink("hygiene furniture layout changed")


func _request_action_runner_rethink(reason: String) -> void:
	var runner := _get_action_runner()
	if runner == null:
		return
	var active_action_id := runner.get_active_action_id()
	if active_action_id == hygiene_action_id:
		return
	if active_action_id == CharacterNeedActionIds.REST or active_action_id == CharacterNeedActionIds.HYDRATE:
		return
	runner.request_rethink(reason)


func _is_hygiene_need_requested() -> bool:
	if _needs_module == null:
		return false
	return _needs_module.get_need_ratio(hygiene_need_id, 1.0) <= hygiene_request_ratio


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


func _is_shower_furniture(furniture: Node2D) -> bool:
	if not super._is_shower_furniture(furniture):
		return false
	return _can_use_shower(furniture)


func _set_hygiene_target(shower: Node2D) -> void:
	var previous_shower := _target_shower
	super._set_hygiene_target(shower)
	if previous_shower != _target_shower:
		_clear_shower_build_lock(previous_shower)
		_clear_shower_reservation(previous_shower)
	_claim_current_shower()


func _clear_hygiene_target() -> void:
	var shower := _target_shower
	_clear_shower_build_lock(shower)
	_clear_shower_reservation(shower)
	super._clear_hygiene_target()


func _begin_showering(start_progress: float) -> void:
	_claim_current_shower()
	_lock_current_shower()
	super._begin_showering(start_progress)


func _can_use_shower(shower: Node2D) -> bool:
	if shower == null or not is_instance_valid(shower):
		return false
	if shower.has_meta(SHOWER_RESERVED_BY_META):
		return int(shower.get_meta(SHOWER_RESERVED_BY_META, 0)) == get_instance_id()
	if shower.has_meta(BUILD_LOCK_META) and bool(shower.get_meta(BUILD_LOCK_META, false)):
		return false
	return true


func _claim_current_shower() -> void:
	if _target_shower == null or not is_instance_valid(_target_shower):
		return
	if not _can_use_shower(_target_shower):
		return
	_target_shower.set_meta(SHOWER_RESERVED_BY_META, get_instance_id())
	_target_shower.set_meta(SHOWER_RESERVED_NAME_META, _body.name if _body != null else name)
	_target_shower.set_meta(SHOWER_RESERVED_REASON_META, "HygieneTarget")


func _clear_shower_reservation(shower: Node2D) -> void:
	if shower == null or not is_instance_valid(shower):
		return
	if int(shower.get_meta(SHOWER_RESERVED_BY_META, 0)) != get_instance_id():
		return
	if shower.has_meta(SHOWER_RESERVED_BY_META):
		shower.remove_meta(SHOWER_RESERVED_BY_META)
	if shower.has_meta(SHOWER_RESERVED_NAME_META):
		shower.remove_meta(SHOWER_RESERVED_NAME_META)
	if shower.has_meta(SHOWER_RESERVED_REASON_META):
		shower.remove_meta(SHOWER_RESERVED_REASON_META)


func _lock_current_shower() -> void:
	if _target_shower == null or not is_instance_valid(_target_shower):
		return
	if int(_target_shower.get_meta(SHOWER_RESERVED_BY_META, 0)) != get_instance_id():
		return
	_locked_shower = _target_shower
	_locked_shower.set_meta(BUILD_LOCK_META, true)
	_locked_shower.set_meta(BUILD_LOCK_REASON_META, SHOWER_LOCK_REASON)
	_locked_shower.set_meta(SHOWER_BUILD_LOCK_OWNER_META, get_instance_id())


func _clear_shower_build_lock(shower: Node2D) -> void:
	var lock_target := shower
	if lock_target == null:
		lock_target = _locked_shower
	if lock_target != null and is_instance_valid(lock_target):
		if int(lock_target.get_meta(SHOWER_BUILD_LOCK_OWNER_META, 0)) == get_instance_id():
			if lock_target.has_meta(BUILD_LOCK_META):
				lock_target.remove_meta(BUILD_LOCK_META)
			if lock_target.has_meta(BUILD_LOCK_REASON_META):
				lock_target.remove_meta(BUILD_LOCK_REASON_META)
			if lock_target.has_meta(SHOWER_BUILD_LOCK_OWNER_META):
				lock_target.remove_meta(SHOWER_BUILD_LOCK_OWNER_META)
	if _locked_shower == lock_target:
		_locked_shower = null
