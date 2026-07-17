extends AICharacterReservedCraftBehaviorModule
class_name AICharacterActionRunnerCraftModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")
const NODE_ACTION_ADAPTER_SCRIPT := preload("res://Scripts/Characters/Actions/Core/AICharacterNodeActionAdapter.gd")

@export var action_request_module_path: NodePath = NodePath("../AICharacterActionRequestModule")
@export var craft_action_id: StringName = &"crafting"
@export var action_runner_priority: int = 30
@export var action_runner_base_score: float = 190.0
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
	_connect_craft_signals()


func _exit_tree() -> void:
	_unregister_from_action_runner()
	cancel_action_runner_craft()
	super._exit_tree()


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	_resolve_action_request_module()
	if _action_request_module == null or recipe == null or recipe.output_item == null:
		return false
	var safe_quantity := maxi(quantity, 1)
	var payload := {
		"recipe": recipe,
		"quantity": safe_quantity,
	}
	var request_id := _action_request_module.submit_request(
		craft_action_id,
		payload,
		_get_recipe_display_name(recipe),
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
	if active_action_id == craft_action_id or _is_higher_priority_need_action(active_action_id):
		return true
	runner.request_rethink("craft requested")
	return true


func cancel_requested_craft() -> void:
	_resolve_action_request_module()
	if _action_request_module == null or not _action_request_module.is_current_action(craft_action_id):
		return
	var request_id := _action_request_module.get_current_request_id()
	if is_active() or _ingredients_held:
		cancel_crafting(true)
	_action_request_module.cancel_current_request(request_id)
	_request_runner_rethink("craft request canceled")


func can_start_action_runner_craft() -> bool:
	_resolve_refs()
	_resolve_action_request_module()
	if not action_runner_registration_enabled:
		return false
	if _body == null or not is_instance_valid(_body) or _action_request_module == null:
		return false
	if _action_runner_controlled or is_active():
		return true
	if not _action_request_module.is_current_action(craft_action_id):
		return false
	var recipe := _get_requested_recipe()
	var quantity := _get_requested_quantity()
	if recipe == null or recipe.output_item == null or quantity <= 0:
		_action_request_module.cancel_current_request()
		return false
	if not has_required_ingredients(recipe, quantity):
		return false
	if not has_required_furniture_available(recipe):
		return false
	return true


func get_action_runner_craft_score() -> float:
	if _action_runner_controlled or is_active():
		return action_runner_base_score + 40.0
	if _action_request_module != null and _action_request_module.is_current_action(craft_action_id):
		return action_runner_base_score
	return -INF


func start_action_runner_craft() -> bool:
	if not can_start_action_runner_craft():
		return false
	var recipe := _get_requested_recipe()
	var quantity := _get_requested_quantity()
	if recipe == null or quantity <= 0:
		return false
	_action_runner_controlled = true
	_active_request_id = _action_request_module.get_current_request_id()
	_request_completed_during_action = false
	_request_interrupted_during_action = false
	if is_active():
		return true
	if super.request_craft(recipe, quantity):
		return true
	_action_runner_controlled = false
	_active_request_id = AICharacterActionRequestModule.INVALID_REQUEST_ID
	return false


func tick_action_runner_craft(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		if _request_completed_during_action:
			return AICharacterActionResult.completed("craft completed")
		if not _is_active_request_current():
			return AICharacterActionResult.completed("craft request changed")
		if _request_interrupted_during_action:
			return AICharacterActionResult.completed("craft interrupted; request retained")
		return AICharacterActionResult.completed("craft stopped; request retained")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_craft() -> void:
	var should_resume := true
	if _action_request_module != null and _is_active_request_current():
		should_resume = _action_request_module.should_resume_current_after_interrupt()
	if is_active() or _ingredients_held:
		cancel_crafting(true)
	if not should_resume and _action_request_module != null and _is_active_request_current():
		_action_request_module.cancel_current_request(_active_request_id)
	_action_runner_controlled = false
	_release_action_runner_move_slot()


func cleanup_action_runner_craft() -> void:
	_action_runner_controlled = false
	_active_request_id = AICharacterActionRequestModule.INVALID_REQUEST_ID
	_request_completed_during_action = false
	_request_interrupted_during_action = false
	_release_action_runner_move_slot()


func get_action_runner_craft_debug_summary() -> String:
	return "craft runner_controlled=%s active=%s crafting=%s request=%d registered=%s %s" % [
		str(_action_runner_controlled),
		str(is_active()),
		str(is_crafting()),
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
	if runner.has_method("has_package") and runner.call("has_package", craft_action_id) == true:
		_registered_with_action_runner = true
		return
	var adapter := NODE_ACTION_ADAPTER_SCRIPT.new() as AICharacterNodeActionAdapter
	if adapter == null or _body == null:
		return
	adapter.action_id = craft_action_id
	adapter.display_name = "制作中"
	adapter.priority = action_runner_priority
	adapter.base_score = action_runner_base_score
	adapter.action_node_path = _body.get_path_to(self)
	adapter.can_start_method = &"can_start_action_runner_craft"
	adapter.score_method = &"get_action_runner_craft_score"
	adapter.start_method = &"start_action_runner_craft"
	adapter.tick_method = &"tick_action_runner_craft"
	adapter.tick_pass_delta = true
	adapter.active_check_method = &""
	adapter.complete_when_inactive = false
	adapter.cancel_method_names = PackedStringArray(["cancel_action_runner_craft"])
	adapter.cleanup_method_names = PackedStringArray(["cleanup_action_runner_craft"])
	adapter.debug_summary_method = &"get_action_runner_craft_debug_summary"
	adapter.progress_visible_method = &"is_action_progress_visible"
	adapter.progress_ratio_method = &"get_action_progress_ratio"
	adapter.item_visible_method = &"is_action_item_display_visible"
	adapter.item_icon_method = &"get_action_item_icon_path"
	if runner.has_method("add_package"):
		_registered_with_action_runner = runner.call("add_package", adapter) == true


func _unregister_from_action_runner() -> void:
	if not _registered_with_action_runner:
		return
	var runner := _get_action_runner()
	if runner != null and runner.has_method("remove_package"):
		runner.call("remove_package", craft_action_id)
	_registered_with_action_runner = false


func _connect_craft_signals() -> void:
	var completed_callable := Callable(self, "_on_action_runner_craft_completed")
	if not craft_completed.is_connected(completed_callable):
		craft_completed.connect(completed_callable)
	var interrupted_callable := Callable(self, "_on_action_runner_craft_interrupted")
	if not craft_interrupted.is_connected(interrupted_callable):
		craft_interrupted.connect(interrupted_callable)


func _on_action_runner_craft_completed(_recipe: CraftRecipeData, _quantity: int) -> void:
	_request_completed_during_action = true
	if _action_request_module != null and _is_active_request_current():
		_action_request_module.complete_current_request(_active_request_id)


func _on_action_runner_craft_interrupted(_recipe: CraftRecipeData, _quantity: int) -> void:
	_request_interrupted_during_action = true


func _get_requested_recipe() -> CraftRecipeData:
	var payload := _get_requested_payload()
	if payload.is_empty():
		return null
	var recipe_value: Variant = payload.get("recipe", null)
	if recipe_value is CraftRecipeData:
		return recipe_value as CraftRecipeData
	return null


func _get_requested_quantity() -> int:
	var payload := _get_requested_payload()
	return maxi(int(payload.get("quantity", 0)), 0)


func _get_requested_payload() -> Dictionary:
	if _action_request_module == null or not _action_request_module.is_current_action(craft_action_id):
		return {}
	var payload: Variant = _action_request_module.get_current_payload()
	if payload is Dictionary:
		return payload as Dictionary
	return {}


func _is_active_request_current() -> bool:
	return (
		_action_request_module != null
		and _action_request_module.is_current_action(craft_action_id)
		and _action_request_module.get_current_request_id() == _active_request_id
	)


func _is_higher_priority_need_action(action_id: StringName) -> bool:
	return (
		action_id == CharacterNeedActionIds.REST
		or action_id == CharacterNeedActionIds.HYDRATE
		or action_id == CharacterNeedActionIds.MAINTAIN
	)


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
