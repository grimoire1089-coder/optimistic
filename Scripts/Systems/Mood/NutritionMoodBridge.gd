extends Node
class_name NutritionMoodBridge

@export var needs_module_path: NodePath = NodePath("../CharacterNeedsModule")
@export var mood_module_path: NodePath = NodePath("../CharacterMoodModule")
@export var nutrition_need_id: StringName = CharacterNeedIds.HUNGER
@export_range(0.0, 1.0, 0.01) var hungry_threshold_ratio: float = 0.50
@export_range(0.0, 1.0, 0.01) var malnutrition_threshold_ratio: float = 0.30
@export_range(0.0, 1.0, 0.01) var shutdown_risk_threshold_ratio: float = 0.10
@export var hungry_entry_path: String = "res://Data/Mood/Entries/nutrition_hungry.tres"
@export var malnutrition_entry_path: String = "res://Data/Mood/Entries/nutrition_malnutrition.tres"
@export var shutdown_risk_entry_path: String = "res://Data/Mood/Entries/nutrition_shutdown_risk.tres"

var _needs_module: CharacterNeedsModule
var _mood_module: CharacterMoodModule
var _hungry_entry: CharacterMoodEntryData
var _malnutrition_entry: CharacterMoodEntryData
var _shutdown_risk_entry: CharacterMoodEntryData


func _ready() -> void:
	_resolve_modules()
	_load_entries()
	_connect_needs_module()
	call_deferred("refresh")


func refresh() -> void:
	if _needs_module == null or _mood_module == null:
		return
	var ratio := _needs_module.get_need_ratio(nutrition_need_id, 1.0)
	if ratio <= shutdown_risk_threshold_ratio:
		_apply_only(_shutdown_risk_entry)
		return
	if ratio <= malnutrition_threshold_ratio:
		_apply_only(_malnutrition_entry)
		return
	if ratio <= hungry_threshold_ratio:
		_apply_only(_hungry_entry)
		return
	_clear_all()


func _apply_only(entry_data: CharacterMoodEntryData) -> void:
	if entry_data == null:
		_clear_all()
		return
	_forget_if_not(entry_data, _hungry_entry)
	_forget_if_not(entry_data, _malnutrition_entry)
	_forget_if_not(entry_data, _shutdown_risk_entry)
	if not _mood_module.has_entry(entry_data.entry_id):
		_mood_module.add_entry(entry_data)


func _forget_if_not(active_entry: CharacterMoodEntryData, target_entry: CharacterMoodEntryData) -> void:
	if target_entry == null or active_entry == target_entry:
		return
	if _mood_module.has_entry(target_entry.entry_id):
		_mood_module.forget_entry(target_entry.entry_id)


func _clear_all() -> void:
	_forget_entry(_hungry_entry)
	_forget_entry(_malnutrition_entry)
	_forget_entry(_shutdown_risk_entry)


func _forget_entry(entry_data: CharacterMoodEntryData) -> void:
	if entry_data == null or _mood_module == null:
		return
	if _mood_module.has_entry(entry_data.entry_id):
		_mood_module.forget_entry(entry_data.entry_id)


func _resolve_modules() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	_mood_module = get_node_or_null(mood_module_path) as CharacterMoodModule


func _load_entries() -> void:
	_hungry_entry = _load_entry(hungry_entry_path)
	_malnutrition_entry = _load_entry(malnutrition_entry_path)
	_shutdown_risk_entry = _load_entry(shutdown_risk_entry_path)


func _load_entry(path: String) -> CharacterMoodEntryData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if resource is CharacterMoodEntryData:
		return resource as CharacterMoodEntryData
	return null


func _connect_needs_module() -> void:
	if _needs_module == null:
		return
	var changed_callable := Callable(self, "_on_need_changed")
	if not _needs_module.need_changed.is_connected(changed_callable):
		_needs_module.need_changed.connect(changed_callable)


func _on_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	if need_id != nutrition_need_id:
		return
	refresh()
