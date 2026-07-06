extends Resource
class_name FoodItemData

const DIRECT_NEED_EFFECT_SUFFIX := "need_values"

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category_id: StringName = &"foods"
@export_range(1, 999, 1) var stack_max: int = 99
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(0, 999999, 1) var sell_price: int = 0
@export var can_discard: bool = true
@export var can_transfer: bool = true

@export_group("Need Values")
@export_range(0.0, 999.0, 1.0, "or_greater", "suffix:pt") var nutrition_value: float = 0.0
@export_range(0.0, 999.0, 1.0, "or_greater", "suffix:pt") var hydration_value: float = 0.0
@export var extra_need_values: Dictionary = {}
@export_group("")

@export var need_effect: NeedEffectData:
	set(value):
		_raw_need_effect = value
		_runtime_need_effect = null
	get:
		return get_effective_need_effect()

var _raw_need_effect: NeedEffectData
var _runtime_need_effect: NeedEffectData


func get_icon_path() -> String:
	if icon == null:
		return ""
	return icon.resource_path


func get_need_effect_path() -> String:
	if _raw_need_effect == null:
		return ""
	return _raw_need_effect.resource_path


func get_need_values(include_legacy_effect: bool = true) -> Dictionary:
	var result: Dictionary = {}
	if include_legacy_effect and _raw_need_effect != null:
		_add_need_values(result, _raw_need_effect.values)
	if not is_zero_approx(nutrition_value):
		_add_need_value(result, CharacterNeedIds.HUNGER, nutrition_value)
	if not is_zero_approx(hydration_value):
		_add_need_value(result, CharacterNeedIds.WATER, hydration_value)
	_add_need_values(result, extra_need_values)
	return result


func get_effective_need_effect() -> NeedEffectData:
	if _raw_need_effect != null and not _has_direct_need_values():
		return _raw_need_effect

	var values := get_need_values(true)
	if values.is_empty():
		_runtime_need_effect = null
		return null

	if _runtime_need_effect == null:
		_runtime_need_effect = NeedEffectData.new()
	_runtime_need_effect.effect_id = _get_direct_need_effect_id()
	_runtime_need_effect.display_name = _get_direct_need_effect_name()
	_runtime_need_effect.values = values
	return _runtime_need_effect


func to_inventory_entry(amount: int = 1) -> Dictionary:
	return {
		"id": item_id,
		"category_id": category_id,
		"display_name": display_name,
		"amount": max(amount, 1),
		"icon_path": get_icon_path(),
		"stack_max": stack_max,
		"description": description,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"can_discard": can_discard,
		"can_transfer": can_transfer,
		"need_effect_path": get_need_effect_path(),
		"nutrition_value": nutrition_value,
		"hydration_value": hydration_value,
		"extra_need_values": extra_need_values.duplicate(true),
		"need_values": get_need_values(true),
	}


func _has_direct_need_values() -> bool:
	return not is_zero_approx(nutrition_value) or not is_zero_approx(hydration_value) or not extra_need_values.is_empty()


func _get_direct_need_effect_id() -> StringName:
	var base_id := String(item_id)
	if base_id.is_empty():
		base_id = "food_item"
	return StringName("%s_%s" % [base_id, DIRECT_NEED_EFFECT_SUFFIX])


func _get_direct_need_effect_name() -> String:
	if not display_name.strip_edges().is_empty():
		return "%s 効果" % display_name.strip_edges()
	return "Food Need Values"


func _add_need_values(target: Dictionary, source: Dictionary) -> void:
	for raw_need_id in source.keys():
		_add_need_value(target, StringName(raw_need_id), float(source[raw_need_id]))


func _add_need_value(target: Dictionary, need_id: StringName, amount: float) -> void:
	if need_id == &"" or is_zero_approx(amount):
		return
	target[need_id] = float(target.get(need_id, 0.0)) + amount
