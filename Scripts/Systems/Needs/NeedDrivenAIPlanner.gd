extends Node
class_name NeedDrivenAIPlanner

@export var needs_module_path: NodePath
@export var low_only: bool = true
@export var fallback_action_id: StringName = CharacterNeedActionIds.IDLE

var _needs_module: CharacterNeedsModule

func _ready() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule

func get_next_action_id() -> StringName:
	var module := _get_module()
	if module == null:
		return fallback_action_id
	var lowest_need := module.get_lowest_need()
	if lowest_need == null or lowest_need.definition == null:
		return fallback_action_id
	if low_only and not lowest_need.is_low():
		return fallback_action_id
	return get_action_id_for_need(lowest_need.definition.need_id)

func get_action_id_for_need(need_id: StringName) -> StringName:
	match need_id:
		CharacterNeedIds.HUNGER:
			return CharacterNeedActionIds.EAT
		CharacterNeedIds.WATER:
			return CharacterNeedActionIds.HYDRATE
		CharacterNeedIds.ENERGY:
			return CharacterNeedActionIds.REST
		CharacterNeedIds.HYGIENE:
			return CharacterNeedActionIds.MAINTAIN
		CharacterNeedIds.FUN:
			return CharacterNeedActionIds.PLAY
		CharacterNeedIds.SOCIAL:
			return CharacterNeedActionIds.CHAT
		_:
			return fallback_action_id

func get_current_priority() -> float:
	var module := _get_module()
	if module == null:
		return 0.0
	var need_id := module.get_lowest_need_id()
	if need_id == &"":
		return 0.0
	return module.get_need_priority(need_id)

func get_current_need_id() -> StringName:
	var module := _get_module()
	if module == null:
		return &""
	return module.get_lowest_need_id()

func _get_module() -> CharacterNeedsModule:
	if _needs_module != null:
		return _needs_module
	_needs_module = get_node_or_null(needs_module_path) as NeedDrivenAIPlanner
	return _needs_module
