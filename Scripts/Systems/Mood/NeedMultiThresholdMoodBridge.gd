extends Node
class_name NeedMultiThresholdMoodBridge

@export var needs_module_path: NodePath = NodePath("../CharacterNeedsModule")
@export var mood_module_path: NodePath = NodePath("../CharacterMoodModule")
@export var watched_need_id: StringName = CharacterNeedIds.HUNGER
@export var threshold_entries: Array[Dictionary] = [
	{
		"threshold_ratio": 0.30,
		"entry_path": "res://Data/Mood/Entries/hunger_low.tres",
	},
	{
		"threshold_ratio": 0.15,
		"entry_path": "res://Data/Mood/Entries/hunger_malnutrition.tres",
	},
	{
		"threshold_ratio": 0.05,
		"entry_path": "res://Data/Mood/Entries/hunger_shutdown_risk.tres",
	},
]

var _needs_module: CharacterNeedsModule
var _mood_module: CharacterMoodModule
var _loaded_entries: Array[Dictionary] = []


func _ready() -> void:
	_resolve_modules()
	_load_entries()
	_connect_needs_module()
	call_deferred("refresh")


func refresh() -> void:
	if _needs_module == null or _mood_module == null:
		return
	if _loaded_entries.is_empty():
		return
	var ratio := _needs_module.get_need_ratio(watched_need_id, 1.0)
	var active_entry: CharacterMoodEntryData = _get_active_entry_for_ratio(ratio)
	for item in _loaded_entries:
		var entry_data := item.get("entry_data", null) as CharacterMoodEntryData
		if entry_data == null:
			continue
		if active_entry != null and entry_data.entry_id == active_entry.entry_id:
			if not _mood_module.has_entry(entry_data.entry_id):
				_mood_module.add_entry(entry_data)
		elif _mood_module.has_entry(entry_data.entry_id):
			_mood_module.forget_entry(entry_data.entry_id)


func _get_active_entry_for_ratio(ratio: float) -> CharacterMoodEntryData:
	var active_entry: CharacterMoodEntryData = null
	var active_threshold := -1.0
	for item in _loaded_entries:
		var threshold := float(item.get("threshold_ratio", 0.0))
		var entry_data := item.get("entry_data", null) as CharacterMoodEntryData
		if entry_data == null:
			continue
		if ratio <= threshold and threshold > active_threshold:
			active_threshold = threshold
			active_entry = entry_data
	return active_entry


func _resolve_modules() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	_mood_module = get_node_or_null(mood_module_path) as CharacterMoodModule


func _load_entries() -> void:
	_loaded_entries.clear()
	for item in threshold_entries:
		var path := String(item.get("entry_path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var resource := load(path)
		if not resource is CharacterMoodEntryData:
			continue
		_loaded_entries.append({
			"threshold_ratio": float(item.get("threshold_ratio", 0.0)),
			"entry_data": resource as CharacterMoodEntryData,
		})


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
