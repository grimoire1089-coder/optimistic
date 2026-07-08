extends RefCounted
class_name AICharacterActionRunner

const PHASE_IDLE: StringName = &"idle"
const PHASE_THINKING: StringName = &"thinking"
const PHASE_STARTING: StringName = &"starting"
const PHASE_RUNNING: StringName = &"running"
const PHASE_COMPLETED: StringName = &"completed"
const PHASE_FAILED: StringName = &"failed"
const PHASE_CANCELED: StringName = &"canceled"

var idle_think_interval_seconds: float = 0.25
var current_action_id: StringName = &""
var current_phase: StringName = PHASE_IDLE
var last_fail_reason: String = ""

var _actor: Node
var _context := AICharacterActionContext.new()
var _packages: Array[AICharacterActionPackage] = []
var _active_package: AICharacterActionPackage
var _idle_think_timer: float = 0.0


func setup(actor: Node, packages: Array[AICharacterActionPackage] = []) -> void:
	shutdown()
	_actor = actor
	_context.bind_actor(_actor, self)
	set_packages(packages)
	current_phase = PHASE_IDLE
	_idle_think_timer = 0.0


func shutdown() -> void:
	_cancel_active_action("runner shutdown")
	for package in _packages:
		if package != null:
			package.unbind()
	_packages.clear()
	_active_package = null
	_actor = null
	_context.clear()
	current_action_id = &""
	current_phase = PHASE_IDLE
	last_fail_reason = ""
	_idle_think_timer = 0.0


func set_packages(packages: Array[AICharacterActionPackage], duplicate_resources: bool = true) -> void:
	_cancel_active_action("packages changed")
	for package in _packages:
		if package != null:
			package.unbind()
	_packages.clear()

	for package in packages:
		if package == null:
			continue
		var runtime_package := package
		if duplicate_resources:
			runtime_package = package.duplicate(true) as AICharacterActionPackage
		if runtime_package == null:
			continue
		runtime_package.bind(_actor)
		_packages.append(runtime_package)


func physics_update(delta: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	_context.bind_actor(_actor, self)

	if _active_package == null:
		_tick_idle(delta)
		return

	_tick_active(delta)


func cancel_current_action(reason: String = "canceled") -> void:
	_cancel_active_action(reason)
	current_phase = PHASE_CANCELED
	current_action_id = &""
	_idle_think_timer = 0.0


func has_active_action() -> bool:
	return _active_package != null


func get_active_action_id() -> StringName:
	if _active_package == null:
		return &""
	return _active_package.action_id


func get_current_action_display_text() -> String:
	if _active_package == null:
		return "待機中"
	return _active_package.get_action_display_text()


func get_debug_summary() -> String:
	if _active_package == null:
		if last_fail_reason.is_empty():
			return "action=idle phase=%s packages=%d" % [String(current_phase), _packages.size()]
		return "action=idle phase=%s packages=%d last_fail=%s" % [String(current_phase), _packages.size(), last_fail_reason]
	return "action=%s phase=%s %s" % [
		String(_active_package.action_id),
		String(current_phase),
		_active_package.get_debug_summary(),
	]


func _tick_idle(delta: float) -> void:
	_idle_think_timer = maxf(_idle_think_timer - maxf(delta, 0.0), 0.0)
	if _idle_think_timer > 0.0:
		return
	_think_and_start_next_action()
	if _active_package == null:
		_idle_think_timer = idle_think_interval_seconds


func _think_and_start_next_action() -> void:
	current_phase = PHASE_THINKING
	last_fail_reason = ""

	var best_package: AICharacterActionPackage = null
	var best_score := -INF

	for package in _packages:
		if package == null:
			continue
		if not package.can_start(_context):
			continue
		var score := package.get_score(_context)
		score += float(package.priority)
		if best_package == null or score > best_score:
			best_package = package
			best_score = score

	if best_package == null:
		current_action_id = &""
		current_phase = PHASE_IDLE
		return

	current_phase = PHASE_STARTING
	if not best_package.start(_context):
		last_fail_reason = "failed to start %s" % String(best_package.action_id)
		best_package.cleanup(_context)
		current_action_id = &""
		current_phase = PHASE_FAILED
		return

	_active_package = best_package
	current_action_id = _active_package.action_id
	current_phase = PHASE_RUNNING


func _tick_active(delta: float) -> void:
	var result := _active_package.tick(_context, delta)
	if result == null:
		last_fail_reason = "tick returned null"
		_finish_active_action(PHASE_FAILED)
		return

	_context.apply_movement_result(result)

	if result.is_running():
		current_phase = PHASE_RUNNING
		return

	if result.is_completed():
		_finish_active_action(PHASE_COMPLETED)
		return

	if result.is_failed():
		last_fail_reason = result.fail_reason
		_finish_active_action(PHASE_FAILED)
		return

	if result.is_canceled():
		last_fail_reason = result.fail_reason
		_finish_active_action(PHASE_CANCELED)
		return

	last_fail_reason = "unknown result status: %s" % String(result.status)
	_finish_active_action(PHASE_FAILED)


func _finish_active_action(phase: StringName) -> void:
	if _active_package != null:
		_active_package.cleanup(_context)
	_active_package = null
	current_action_id = &""
	current_phase = phase
	_idle_think_timer = 0.0


func _cancel_active_action(reason: String) -> void:
	if _active_package == null:
		return
	last_fail_reason = reason
	_active_package.cancel(_context)
	_active_package.cleanup(_context)
	_active_package = null
	current_action_id = &""
	_idle_think_timer = 0.0
