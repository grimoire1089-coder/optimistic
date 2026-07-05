extends Node
class_name NeedThresholdMoodBridge

@export var needs_module_path: NodePath = NodePath("../CharacterNeedsModule")
@export var mood_module_path: NodePath = NodePath("../CharacterMoodModule")
@export var watched_need_id: StringName = CharacterNeedIds.ENERGY
@export_range(0.0, 1.0, 0.01) var threshold_ratio: float = 0.33
@export var entry_path: String = "res://Data/Mood/Entries/tired.tres"

var _needs_module: CharacterNeedsModule
var _mood_module: CharacterMoodModule
var _entry_data: CharacterMoodEntryData


func _ready() -> void:
	_resolve_modules()
	_load_entry_data()
	_connect_needs_module()
	call_deferred("refresh")


func refresh() -> void:
	if _needs_module == null or _mood_module == null or _entry_data == null:
		return
	var ratio := _needs_module.get_need_ratio(watched_need_id, 1.0)
	if ratio <= threshold_ratio:
		if not _mood_module.has_entry(_entry_data.entry_id):
			_mood_module.add_entry(_entry_data)
		return
	if _mood_module.has_entry(_entry_data.entry_id):
		_mood_module.forget_entry(_entry_data.entry_id)


func _resolve_modules() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	_mood_module = get_node_or_null(mood_module_path) as CharacterMoodModule


func _load_entry_data() -> void:
	if entry_path.is_empty():
		return
	if not ResourceLoader.exists(entry_path):
		return
	var resource := load(entry_path)
	if resource is CharacterMoodEntryData:
		_entry_data = resource as CharacterMoodEntryData


func _connect_needs_module() -> void:
	if _needs_module == null:
		return
	var changed_callable := Callable(self, "_on_need_changed")
	if not _needs_module.need_changed.is_connected(changed_callable):
		_needs_module.need_changed.connect(changed_callable)


func _on_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	if need_id != watched_need_id:
		return
	refresh()
