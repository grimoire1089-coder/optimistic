extends AICharacterCraftBehaviorModule
class_name AICharacterReservedCraftBehaviorModule

signal craft_interrupted(recipe: CraftRecipeData, quantity: int)

const CRAFT_RESERVED_BY_META := &"ai_craft_reserved_by"
const CRAFT_RESERVED_NAME_META := &"ai_craft_reserved_name"
const CRAFT_RESERVED_REASON_META := &"ai_craft_reserved_reason"
const CRAFT_BUILD_LOCK_OWNER_META := &"ai_craft_build_lock_owner"
const SHARED_BUILD_LOCK_META := &"build_locked_by_sleep"
const SHARED_BUILD_LOCK_REASON_META := &"build_lock_reason"

var _ingredients_held := false
var _locked_craft_furniture: Node2D


func setup(body: CharacterBody2D) -> void:
	super.setup(body)
	var completed_callable := Callable(self, "_on_craft_completed")
	if not craft_completed.is_connected(completed_callable):
		craft_completed.connect(completed_callable)


func _exit_tree() -> void:
	cancel_crafting(true)


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	var started := super.request_craft(recipe, quantity)
	if not started:
		return false
	if _target_furniture == null:
		return true
	if _reserve_target_furniture(_target_furniture):
		return true
	cancel_crafting(true)
	return false


func cancel_crafting(refund_ingredients: bool = true) -> void:
	var interrupted_recipe := _recipe
	var interrupted_quantity := _quantity
	var had_commitment := _is_active or _ingredients_held or _target_furniture != null or _locked_craft_furniture != null
	if refund_ingredients:
		_refund_ingredients()
	_reset_action()
	if had_commitment and interrupted_recipe != null:
		craft_interrupted.emit(interrupted_recipe, interrupted_quantity)


func is_crafting() -> bool:
	return _is_crafting


func is_moving() -> bool:
	return _is_moving


func has_required_ingredients(recipe: CraftRecipeData, quantity: int) -> bool:
	_resolve_refs()
	if recipe == null or recipe.output_item == null or _inventory_module == null:
		return false
	var safe_quantity := maxi(quantity, 1)
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		var needed := ingredient.amount * safe_quantity
		if _get_inventory_item_amount(ingredient.item_data.category_id, ingredient.item_data.item_id) < needed:
			return false
	return true


func has_required_furniture_available(recipe: CraftRecipeData) -> bool:
	_resolve_refs()
	if recipe == null:
		return false
	if recipe.required_furniture_ids.is_empty():
		return true
	return _find_required_furniture(recipe.required_furniture_ids) != null


func get_debug_movement_summary() -> String:
	return "craft active=%s moving=%s crafting=%s held=%s target=%s locked=%s path=%d" % [
		str(_is_active),
		str(_is_moving),
		str(_is_crafting),
		str(_ingredients_held),
		str(_target_furniture != null),
		str(_locked_craft_furniture != null),
		_path_cells.size(),
	]


func _consume_ingredients() -> bool:
	if _ingredients_held:
		return false
	var consumed := super._consume_ingredients()
	_ingredients_held = consumed
	return consumed


func _refund_ingredients() -> void:
	if not _ingredients_held:
		return
	super._refund_ingredients()
	_ingredients_held = false


func _find_required_furniture(required_ids: PackedStringArray) -> Node2D:
	if _furniture_root == null or _body == null or _room_map == null:
		return null
	var nearest: Node2D = null
	var nearest_distance := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _required_ids_has(required_ids, _get_furniture_id(furniture)):
			continue
		if not _is_craft_furniture_available_for_actor(furniture):
			continue
		var use_cell := _get_furniture_use_cell(furniture)
		if use_cell == INVALID_GRID_POSITION:
			continue
		var use_position := _room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())
		var distance := _body.global_position.distance_squared_to(use_position)
		if nearest == null or distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
	return nearest


func _begin_crafting() -> void:
	if _target_furniture != null:
		if not _lock_target_furniture(_target_furniture):
			cancel_crafting(true)
			return
		_clear_furniture_reservation(_target_furniture)
	super._begin_crafting()


func _reset_action() -> void:
	var target := _target_furniture
	_clear_furniture_reservation(target)
	_clear_furniture_build_lock(_locked_craft_furniture)
	super._reset_action()


func _on_craft_completed(_recipe_data: CraftRecipeData, _quantity_value: int) -> void:
	_ingredients_held = false


func _is_craft_furniture_available_for_actor(furniture: Node2D) -> bool:
	if furniture == null or not is_instance_valid(furniture):
		return false
	if furniture.has_meta(SHARED_BUILD_LOCK_META) and bool(furniture.get_meta(SHARED_BUILD_LOCK_META, false)):
		return int(furniture.get_meta(CRAFT_BUILD_LOCK_OWNER_META, 0)) == get_instance_id()
	if not furniture.has_meta(CRAFT_RESERVED_BY_META):
		return true
	return int(furniture.get_meta(CRAFT_RESERVED_BY_META, 0)) == get_instance_id()


func _reserve_target_furniture(furniture: Node2D) -> bool:
	if not _is_craft_furniture_available_for_actor(furniture):
		return false
	furniture.set_meta(CRAFT_RESERVED_BY_META, get_instance_id())
	furniture.set_meta(CRAFT_RESERVED_NAME_META, _body.name if _body != null else name)
	furniture.set_meta(CRAFT_RESERVED_REASON_META, "CraftTarget")
	return true


func _clear_furniture_reservation(furniture: Node2D) -> void:
	if furniture == null or not is_instance_valid(furniture):
		return
	if int(furniture.get_meta(CRAFT_RESERVED_BY_META, 0)) != get_instance_id():
		return
	if furniture.has_meta(CRAFT_RESERVED_BY_META):
		furniture.remove_meta(CRAFT_RESERVED_BY_META)
	if furniture.has_meta(CRAFT_RESERVED_NAME_META):
		furniture.remove_meta(CRAFT_RESERVED_NAME_META)
	if furniture.has_meta(CRAFT_RESERVED_REASON_META):
		furniture.remove_meta(CRAFT_RESERVED_REASON_META)


func _lock_target_furniture(furniture: Node2D) -> bool:
	if not _is_craft_furniture_available_for_actor(furniture):
		return false
	furniture.set_meta(SHARED_BUILD_LOCK_META, true)
	furniture.set_meta(SHARED_BUILD_LOCK_REASON_META, "Crafting")
	furniture.set_meta(CRAFT_BUILD_LOCK_OWNER_META, get_instance_id())
	_locked_craft_furniture = furniture
	return true


func _clear_furniture_build_lock(furniture: Node2D) -> void:
	if furniture == null or not is_instance_valid(furniture):
		if _locked_craft_furniture == furniture:
			_locked_craft_furniture = null
		return
	if int(furniture.get_meta(CRAFT_BUILD_LOCK_OWNER_META, 0)) != get_instance_id():
		return
	if furniture.has_meta(SHARED_BUILD_LOCK_META):
		furniture.remove_meta(SHARED_BUILD_LOCK_META)
	if furniture.has_meta(SHARED_BUILD_LOCK_REASON_META):
		furniture.remove_meta(SHARED_BUILD_LOCK_REASON_META)
	if furniture.has_meta(CRAFT_BUILD_LOCK_OWNER_META):
		furniture.remove_meta(CRAFT_BUILD_LOCK_OWNER_META)
	if _locked_craft_furniture == furniture:
		_locked_craft_furniture = null
