extends Node
class_name AICharacterActionRequestModule

signal current_request_changed(action_id: StringName, request_id: int)
signal request_queued(action_id: StringName, request_id: int)
signal request_completed(action_id: StringName, request_id: int)
signal request_canceled(action_id: StringName, request_id: int)

const INVALID_REQUEST_ID := 0

var _next_request_id := 1
var _current_request: Dictionary = {}
var _pending_request: Dictionary = {}


func submit_request(
	action_id: StringName,
	payload: Variant = null,
	display_name: String = "",
	resume_after_interrupt: bool = true
) -> int:
	if action_id == &"":
		return INVALID_REQUEST_ID
	var request := _make_request(action_id, payload, display_name, resume_after_interrupt)
	if _current_request.is_empty():
		_current_request = request
		_emit_current_request_changed()
		return int(request["id"])
	if _is_same_request(_current_request, request):
		return int(_current_request["id"])
	if not _pending_request.is_empty():
		_emit_request_canceled(_pending_request)
	_pending_request = request
	request_queued.emit(action_id, int(request["id"]))
	return int(request["id"])


func has_current_request() -> bool:
	return not _current_request.is_empty()


func has_pending_request() -> bool:
	return not _pending_request.is_empty()


func is_current_action(action_id: StringName) -> bool:
	return has_current_request() and get_current_action_id() == action_id


func get_current_request_id() -> int:
	return int(_current_request.get("id", INVALID_REQUEST_ID))


func get_current_action_id() -> StringName:
	return StringName(String(_current_request.get("action_id", &"")))


func get_current_payload() -> Variant:
	return _current_request.get("payload", null)


func get_current_display_name() -> String:
	return String(_current_request.get("display_name", ""))


func should_resume_current_after_interrupt() -> bool:
	return bool(_current_request.get("resume_after_interrupt", true))


func complete_current_request(expected_request_id: int = INVALID_REQUEST_ID) -> bool:
	if not _matches_current_request_id(expected_request_id):
		return false
	var completed_request := _current_request
	_current_request = {}
	request_completed.emit(
		StringName(String(completed_request.get("action_id", &""))),
		int(completed_request.get("id", INVALID_REQUEST_ID))
	)
	_promote_pending_request()
	return true


func cancel_current_request(expected_request_id: int = INVALID_REQUEST_ID) -> bool:
	if not _matches_current_request_id(expected_request_id):
		return false
	var canceled_request := _current_request
	_current_request = {}
	_emit_request_canceled(canceled_request)
	_promote_pending_request()
	return true


func cancel_action_requests(action_id: StringName) -> bool:
	var changed := false
	if is_current_action(action_id):
		var canceled_request := _current_request
		_current_request = {}
		_emit_request_canceled(canceled_request)
		changed = true
	if not _pending_request.is_empty() and StringName(String(_pending_request.get("action_id", &""))) == action_id:
		var canceled_pending := _pending_request
		_pending_request = {}
		_emit_request_canceled(canceled_pending)
		changed = true
	if _current_request.is_empty():
		_promote_pending_request()
	return changed


func clear_all_requests() -> void:
	if not _current_request.is_empty():
		_emit_request_canceled(_current_request)
	if not _pending_request.is_empty():
		_emit_request_canceled(_pending_request)
	_current_request = {}
	_pending_request = {}
	_emit_current_request_changed()


func get_debug_summary() -> String:
	return "request current=%s#%d pending=%s#%d" % [
		String(get_current_action_id()),
		get_current_request_id(),
		StringName(String(_pending_request.get("action_id", &""))),
		int(_pending_request.get("id", INVALID_REQUEST_ID)),
	]


func _make_request(
	action_id: StringName,
	payload: Variant,
	display_name: String,
	resume_after_interrupt: bool
) -> Dictionary:
	var request_id := _next_request_id
	_next_request_id += 1
	if _next_request_id <= INVALID_REQUEST_ID:
		_next_request_id = 1
	return {
		"id": request_id,
		"action_id": action_id,
		"payload": payload,
		"display_name": display_name,
		"resume_after_interrupt": resume_after_interrupt,
	}


func _is_same_request(left: Dictionary, right: Dictionary) -> bool:
	if StringName(String(left.get("action_id", &""))) != StringName(String(right.get("action_id", &""))):
		return false
	return left.get("payload", null) == right.get("payload", null)


func _matches_current_request_id(expected_request_id: int) -> bool:
	if _current_request.is_empty():
		return false
	return expected_request_id == INVALID_REQUEST_ID or get_current_request_id() == expected_request_id


func _promote_pending_request() -> void:
	if not _current_request.is_empty():
		return
	if _pending_request.is_empty():
		_emit_current_request_changed()
		return
	_current_request = _pending_request
	_pending_request = {}
	_emit_current_request_changed()


func _emit_current_request_changed() -> void:
	current_request_changed.emit(get_current_action_id(), get_current_request_id())


func _emit_request_canceled(request: Dictionary) -> void:
	request_canceled.emit(
		StringName(String(request.get("action_id", &""))),
		int(request.get("id", INVALID_REQUEST_ID))
	)
