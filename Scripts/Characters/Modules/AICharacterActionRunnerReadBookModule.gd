extends AICharacterReservedReadBookBehaviorModule
class_name AICharacterActionRunnerReadBookModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")
const NODE_ACTION_ADAPTER_SCRIPT := preload("res://Scripts/Characters/Actions/Core/AICharacterNodeActionAdapter.gd")

@export var action_request_module_path: NodePath = NodePath("../AICharacterActionRequestModule")
@export var read_action_id: StringName = &"read_book"
@export var action_runner_priority: int = 30
@export var action_runner_base_score: float = 180.0
@export var action_runner_registration_enabled: bool = true
@export var action_runner_ai_actor_group_name: StringName = &"ai_character_actor"
@export var action_runner_use_shared_move_slot: bool = true

var _action_request_module: AICharacterActionRequestModule
var _action_runner_controlled := false
var _registered_with_action_runner := false
var _active_request_id := AICharacterActionRequestModule.INVALID_REQUEST_ID
var _request_completed_during_action := false
var _request_interrupted_during_action := false


func _ready() -> void:
	call_deferred("_setup_and_register")


func setup(body: CharacterBody2D) -> void:
	super.setup(body)
	_resolve_action_request_module()
	_connect_reading_signals()


func _exit_tree() -> void:
	_unregister_from_action_runner()
	cancel_action_runner_read_book()
	super._exit_tree()


func request_read_skill_book(book: BookData) -> bool:
	_resolve_action_request_module()
	if _action_request_module == null or book == null or not book.is_skill_book():
		return false
	var request_id := _action_request_module.submit_request(
		read_action_id,
		book,
		book.display_name,
		true
	)
	if request_id == AICharacterActionRequestModule.INVALID_REQUEST_ID:
		return false
	if _action_request_module.get_current_request_id() != request_id:
		return true
	var runner := _get_action_runner()
	if runner == null:
		return true
	var active_action_id := runner.get_active_action_id()
	if active_action_id == read_action_id or _is_higher_priority_need_action(active_action_id):
		return true
	runner.request_rethink("read book requested")
	return true


func cancel_requested_reading() -> void:
	_resolve_action_request_module()
	if _action_request_module == null or not _action_request_module.is_current_action(read_action_id):
		return
	var request_id := _action_request_module.get_current_request_id()
	if is_active():
		cancel_reading()
	_action_request_module.cancel_current_request(request_id)
	_request_runner_rethink("read book request canceled")


func can_start_action_runner_read_book() -> bool:
	_resolve_refs()
	_resolve_action_request_module()
	if not action_runner_registration_enabled:
		return false
	if _body == null or not is_instance_valid(_body) or _action_request_module == null:
		return false
	if _action_runner_controlled or is_active():
		return true
	if not _action_request_module.is_current_action(read_action_id):
		return false
	var book := _get_requested_book()
	if book == null or not book.is_skill_book():
		_action_request_module.cancel_current_request()
		return false
	if _is_book_completed(book):
		_action_request_module.complete_current_request()
		return false
	if _should_interrupt_for_need():
		return false
	return true


func get_action_runner_read_book_score() -> float:
	if _action_runner_controlled or is_active():
		return action_runner_base_score + 40.0
	if _action_request_module != null and _action_request_module.is_current_action(read_action_id):
		return action_runner_base_score
	return -INF


func start_action_runner_read_book() -> bool:
	if not can_start_action_runner_read_book():
		return false
	var book := _get_requested_book()
	if book == null:
		return false
	_action_runner_controlled = true
	_active_request_id = _action_request_module.get_current_request_id()
	_request_completed_during_action = false
	_request_interrupted_during_action = false
	if is_active():
		return true
	if request_read_book(book):
		return true
	_action_runner_controlled = false
	_active_request_id = AICharacterActionRequestModule.INVALID_REQUEST_ID
	return false


func tick_action_runner_read_book(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		if _request_completed_during_action:
			return AICharacterActionResult.completed("reading completed")
		if not _is_active_request_current():
			return AICharacterActionResult.completed("reading request changed")
		if _request_interrupted_during_action:
			return AICharacterActionResult.completed("reading interrupted; request retained")
		return AICharacterActionResult.completed("reading stopped; request retained")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_read_book() -> void:
	var should_resume := true
	if _action_request_module != null and _is_active_request_current():
		should_resume = _action_request_module.should_resume_current_after_interrupt()
	if is_active():
		cancel_reading()
	if not should_resume and _action_request_module != null and _is_active_request_current():
		_action_request_module.cancel_current_request(_active_request_id)
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func cleanup_action_runner_read_book() -> void:
	_action_runner_controlled = false
	_active_request_id = AICharacterActionRequestModule.INVALID_REQUEST_ID
	_request_completed_during_action = false
	_request_interrupted_during_action = false
	_release_action_runner_move_slot()


func get_action_runner_read_book_debug_summary() -> String:
	return "read runner_controlled=%s active=%s reading=%s request=%d registered=%s %s" % [
		str(_action_runner_controlled),
		str(is_active()),
		str(is_reading()),
		_active_request_id,
		str(_registered_with_action_runner),
		get_debug_movement_summary(),
	]


func _setup_and_register() -> void:
	if _body == null:
		setup(get_parent() as CharacterBody2D)
	if action_runner_registration_enabled:
		_register_with_action_runner()


func _register_with_action_runner() -> void:
	if _registered_with_action_runner:
		return
	var runner := _get_action_runner()
	if runner == null:
		return
	if runner.has_method("has_package") and runner.call("has_package", read_action_id) == true:
		_registered_with_action_runner = true
		return
	var adapter := NODE_ACTION_ADAPTER_SCRIPT.new() as AICharacterNodeActionAdapter
	if adapter == null or _body == null:
		return
	adapter.action_id = read_action_id
	adapter.display_name = "読書中"
	adapter.priority = action_runner_priority
	adapter.base_score = action_runner_base_score
	adapter.action_node_path = _body.get_path_to(self)
	adapter.can_start_method = &"can_start_action_runner_read_book"
	adapter.score_method = &"get_action_runner_read_book_score"
	adapter.start_method = &"start_action_runner_read_book"
	adapter.tick_method = &"tick_action_runner_read_book"
	adapter.tick_pass_delta = true
	adapter.active_check_method = &""
	adapter.complete_when_inactive = false
	adapter.cancel_method_names = PackedStringArray(["cancel_action_runner_read_book"])
	adapter.cleanup_method_names = PackedStringArray(["cleanup_action_runner_read_book"])
	adapter.debug_summary_method = &"get_action_runner_read_book_debug_summary"
	if runner.has_method("add_package"):
		_registered_with_action_runner = runner.call("add_package", adapter) == true


func _unregister_from_action_runner() -> void:
	if not _registered_with_action_runner:
		return
	var runner := _get_action_runner()
	if runner != null and runner.has_method("remove_package"):
		runner.call("remove_package", read_action_id)
	_registered_with_action_runner = false


func _connect_reading_signals() -> void:
	var completed_callable := Callable(self, "_on_reading_completed")
	if not reading_completed.is_connected(completed_callable):
		reading_completed.connect(completed_callable)
	var interrupted_callable := Callable(self, "_on_reading_interrupted")
	if not reading_interrupted.is_connected(interrupted_callable):
		reading_interrupted.connect(interrupted_callable)


func _on_reading_completed(_book: BookData) -> void:
	_request_completed_during_action = true
	if _action_request_module != null and _is_active_request_current():
		_action_request_module.complete_current_request(_active_request_id)


func _on_reading_interrupted(_book: BookData) -> void:
	_request_interrupted_during_action = true


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


func _resolve_action_request_module() -> void:
	if _action_request_module != null and is_instance_valid(_action_request_module):
		return
	if action_request_module_path.is_empty():
		return
	_action_request_module = get_node_or_null(action_request_module_path) as AICharacterActionRequestModule


func _get_requested_book() -> BookData:
	if _action_request_module == null or not _action_request_module.is_current_action(read_action_id):
		return null
	var payload: Variant = _action_request_module.get_current_payload()
	if payload is BookData:
		return payload as BookData
	return null


func _is_book_completed(book: BookData) -> bool:
	var library := _get_book_library()
	if book == null or library == null or not library.has_method("is_book_completed"):
		return false
	return library.call("is_book_completed", book.get_item_id()) == true


func _is_active_request_current() -> bool:
	return (
		_action_request_module != null
		and _action_request_module.is_current_action(read_action_id)
		and _action_request_module.get_current_request_id() == _active_request_id
	)


func _is_higher_priority_need_action(action_id: StringName) -> bool:
	return (
		action_id == CharacterNeedActionIds.REST
		or action_id == CharacterNeedActionIds.HYDRATE
		or action_id == CharacterNeedActionIds.MAINTAIN
	)


func _request_runner_rethink(reason: String) -> void:
	var runner := _get_action_runner()
	if runner != null:
		runner.request_rethink(reason)


func _get_action_runner() -> AICharacterActionRunner:
	if _body == null or not is_instance_valid(_body):
		return null
	if not _body.has_method("get_ai_action_runner"):
		return null
	return _body.call("get_ai_action_runner") as AICharacterActionRunner
