extends Node
class_name NeedEffectApplier

signal effect_applied(effect_id: StringName)

@export var needs_module_path: NodePath
@export var effect: NeedEffectData

var _needs_module: CharacterNeedsModule

func _ready() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule

func apply() -> void:
	if effect == null:
		return
	var module := _get_module()
	if module == null:
		return
	for need_id in effect.values.keys():
		module.add_need_value(need_id, float(effect.values[need_id]))
	effect_applied.emit(effect.effect_id)

func apply_effect_to_module(target_module: CharacterNeedsModule, target_effect: NeedEffectData) -> void:
	if target_module == null:
		return
	if target_effect == null:
		return
	for need_id in target_effect.values.keys():
		target_module.add_need_value(need_id, float(target_effect.values[need_id]))
	effect_applied.emit(target_effect.effect_id)

func _get_module() -> CharacterNeedsModule:
	if _needs_module != null:
		return _needs_module
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	return _needs_module
