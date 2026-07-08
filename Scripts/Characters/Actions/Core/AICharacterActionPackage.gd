extends Resource
class_name AICharacterActionPackage

@export var action_id: StringName = &"idle"
@export var display_name: String = "待機"
@export var priority: int = 0

var _actor: Node


func bind(actor: Node) -> void:
	_actor = actor


func unbind() -> void:
	cleanup()
	_actor = null


func can_start(_context: AICharacterActionContext) -> bool:
	return false


func get_score(_context: AICharacterActionContext) -> float:
	return 0.0


func start(_context: AICharacterActionContext) -> bool:
	return false


func tick(_context: AICharacterActionContext, _delta: float) -> AICharacterActionResult:
	return AICharacterActionResult.completed()


func cancel(_context: AICharacterActionContext = null) -> void:
	pass


func cleanup(_context: AICharacterActionContext = null) -> void:
	pass


func get_debug_summary() -> String:
	return "%s phase=package" % String(action_id)


func get_action_display_text() -> String:
	if display_name.is_empty():
		return String(action_id)
	return display_name


func is_progress_visible() -> bool:
	return false


func get_progress_ratio() -> float:
	return 0.0


func is_item_display_visible() -> bool:
	return false


func get_item_icon_path() -> String:
	return ""
