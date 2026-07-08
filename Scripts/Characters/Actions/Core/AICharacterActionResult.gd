extends RefCounted
class_name AICharacterActionResult

const STATUS_RUNNING: StringName = &"running"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"
const STATUS_CANCELED: StringName = &"canceled"

var status: StringName = STATUS_RUNNING
var message: String = ""
var fail_reason: String = ""
var owns_movement: bool = false
var velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.ZERO


static func running(p_message: String = "") -> AICharacterActionResult:
	var result := AICharacterActionResult.new()
	result.status = STATUS_RUNNING
	result.message = p_message
	return result


static func moving(p_velocity: Vector2, p_facing_direction: Vector2 = Vector2.ZERO, p_message: String = "") -> AICharacterActionResult:
	var result := AICharacterActionResult.running(p_message)
	result.owns_movement = true
	result.velocity = p_velocity
	result.facing_direction = p_facing_direction
	return result


static func completed(p_message: String = "") -> AICharacterActionResult:
	var result := AICharacterActionResult.new()
	result.status = STATUS_COMPLETED
	result.message = p_message
	return result


static func failed(p_reason: String = "") -> AICharacterActionResult:
	var result := AICharacterActionResult.new()
	result.status = STATUS_FAILED
	result.fail_reason = p_reason
	result.message = p_reason
	return result


static func canceled(p_reason: String = "") -> AICharacterActionResult:
	var result := AICharacterActionResult.new()
	result.status = STATUS_CANCELED
	result.fail_reason = p_reason
	result.message = p_reason
	return result


func is_running() -> bool:
	return status == STATUS_RUNNING


func is_completed() -> bool:
	return status == STATUS_COMPLETED


func is_failed() -> bool:
	return status == STATUS_FAILED


func is_canceled() -> bool:
	return status == STATUS_CANCELED


func is_finished() -> bool:
	return is_completed() or is_failed() or is_canceled()
