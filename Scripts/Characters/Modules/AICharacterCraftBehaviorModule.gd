extends Node
class_name AICharacterCraftBehaviorModule

signal craft_started(recipe: CraftRecipeData, quantity: int)
signal craft_completed(recipe: CraftRecipeData, quantity: int)

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const COOKING_CATEGORY_ID: StringName = &"cooking"
const InventoryLookup := preload("res://Scripts/Characters/Modules/AICharacterInventoryLookup.gd")

@export var inventory_module_path: NodePath = NodePath("../AICharacterInventoryModule")
@export var legacy_inventory_module_path: NodePath = NodePath("")
@export var skills_module_path: NodePath = NodePath("../AICharacterSkillsModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var walk_speed: float = 80.0
@export var use_distance: float = 16.0
@export var stuck_warp_seconds: float = 1.25
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export_range(1, 999, 1) var cooking_experience_per_game_minute: int = 1

var _body: CharacterBody2D
var _inventory_module: Node
var _skills_module: AICharacterSkillsModule
var _furniture_root: Node
var _furniture_placement: Node
var _room_map: RoomMapGridModule
var _clock: GameClockSystem
var _recipe: CraftRecipeData
var _quantity := 1
var _target_furniture: Node2D
var _target_cell := INVALID_GRID_POSITION
var _is_active := false
var _is_moving := false
var _is_crafting := false
var _action_progress_ratio := 0.0
var _craft_timer := 0.0
var _craft_duration_seconds := 1.0
var _last_distance := INF
var _stuck_timer := 0.0
var _facing_direction := Vector2.DOWN
var _path_cells: Array[Vector2i] = []


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	_resolve_refs()
	if _is_active:
		_push_message("制作中です。")
		return false
	if _is_body_sleeping():
		_push_message("睡眠中なので、今は制作できません。")
		return false
	if recipe == null or recipe.output_item == null or _inventory_module == null:
		return false
	_recipe = recipe
	_quantity = maxi(quantity, 1)
	_action_progress_ratio = 0.0
	_craft_timer = 0.0
	_stuck_timer = 0.0
	_last_distance = INF
	_path_cells.clear()
	if not _consume_ingredients():
		_reset_action()
		return false
	if recipe.required_furniture_ids.is_empty():
		_begin_crafting()
		return true
	_target_furniture = _find_required_furniture(recipe.required_furniture_ids)
	if _target_furniture == null:
		_refund_ingredients()
		_push_message("必要家具がありません。")
		_reset_action()
		return false
	_target_cell = _get_furniture_use_cell(_target_furniture)
	if _target_cell == INVALID_GRID_POSITION:
		_refund_ingredients()
		_push_message("家具の前に立てません。")
		_reset_action()
		return false
	_is_active = true
	_is_moving = true
	_is_crafting = false
	_push_message("%s x%dの制作を開始しました。" % [_get_recipe_display_name(recipe), _quantity])
	craft_started.emit(recipe, _quantity)
	return true


func is_active() -> bool:
	return _is_active


func is_action_progress_visible() -> bool:
	return _is_crafting


func get_action_progress_ratio() -> float:
	return clampf(_action_progress_ratio, 0.0, 1.0)


func is_action_item_display_visible() -> bool:
	return _is_crafting and _recipe != null and _recipe.output_item != null


func get_action_item_icon_path() -> String:
	if _recipe == null or _recipe.output_item == null:
		return ""
	return _recipe.output_item.get_icon_path()


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	if not _is_active:
		return Vector2.ZERO
	if _is_crafting:
		_update_crafting(delta)
		return Vector2.ZERO
	if _is_moving:
		return _update_moving(delta)
	return Vector2.ZERO


func _update_moving(delta: float) -> Vector2:
	var target_position := _get_target_position()
	var to_target := target_position - _body.global_position
	var distance := to_target.length()
	_update_stuck(distance, delta)
	_action_progress_ratio = 0.0
	if distance <= use_distance:
		_begin_crafting()
		return Vector2.ZERO
	if _stuck_timer >= stuck_warp_seconds:
		_body.global_position = target_position
		_begin_crafting()
		return Vector2.ZERO
	var path_velocity := _get_grid_path_velocity_to_target(_target_cell)
	if path_velocity != Vector2.ZERO:
		return path_velocity
	_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
	return _facing_direction * walk_speed


func _begin_crafting() -> void:
	_snap_body_to_target_cell()
	_is_active = true
	_is_moving = false
	_is_crafting = true
	_path_cells.clear()
	_craft_timer = 0.0
	_action_progress_ratio = 0.0
	_craft_duration_seconds = _get_craft_duration_seconds()
	if _target_furniture != null:
		var to_furniture := _target_furniture.global_position - _body.global_position
		if to_furniture.length() > 0.1:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_furniture)


func _snap_body_to_target_cell() -> void:
	if _body == null or _room_map == null:
		return
	if not _is_valid_grid_position(_target_cell):
		return
	var target_position := _room_map.grid_to_world_area_center(_target_cell, _get_actor_grid_footprint())
	if _body.global_position.distance_squared_to(target_position) <= 0.001:
		return
	_body.global_position = target_position
	_last_distance = INF


func _update_crafting(delta: float) -> void:
	if _clock != null and (not _clock.is_running or _clock.is_clock_paused):
		return
	var duration := maxf(_craft_duration_seconds, 0.1)
	_craft_timer = minf(_craft_timer + maxf(delta, 0.0), duration)
	var local_ratio := clampf(_craft_timer / duration, 0.0, 1.0)
	_action_progress_ratio = local_ratio
	if _craft_timer >= duration:
		_complete_crafting()


func _complete_crafting() -> void:
	if _recipe == null or _recipe.output_item == null or _inventory_module == null:
		_reset_action()
		return
	var output_amount := _recipe.output_amount * _quantity
	if not _add_food_to_inventory(_recipe.output_item, output_amount):
		_refund_ingredients()
		_push_message("完成品を追加できませんでした。")
		_reset_action()
		return
	_add_skill_experience_for_completed_craft()
	_record_bill_usage_for_completed_craft(_recipe, _quantity, output_amount)
	_push_message("%s x%dを作りました。" % [_get_recipe_display_name(_recipe), output_amount])
	craft_completed.emit(_recipe, _quantity)
	_reset_action()


func _consume_ingredients() -> bool:
	if _inventory_module == null or not _inventory_module.has_method("remove_item"):
		return false
	for ingredient in _recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		var needed := ingredient.amount * _quantity
		var current := _get_inventory_item_amount(ingredient.item_data.category_id, ingredient.item_data.item_id)
		if current < needed:
			_push_message("材料が足りません: %s %d/%d" % [_get_item_display_name(ingredient.item_data), current, needed])
			return false
	for ingredient in _recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		_inventory_module.call("remove_item", ingredient.item_data.category_id, ingredient.item_data.item_id, ingredient.amount * _quantity)
	return true


func _refund_ingredients() -> void:
	if _recipe == null or _inventory_module == null:
		return
	for ingredient in _recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		_add_food_to_inventory(ingredient.item_data, ingredient.amount * _quantity)


func _add_food_to_inventory(item_data: FoodItemData, amount: int) -> bool:
	if _inventory_module == null or item_data == null:
		return false
	if _inventory_module.has_method("add_food_item"):
		return _inventory_module.call("add_food_item", item_data, amount) == true
	if not _inventory_module.has_method("add_item"):
		return false
	return _inventory_module.call(
		"add_item",
		item_data.category_id,
		item_data.item_id,
		item_data.display_name,
		maxi(amount, 1),
		item_data.get_icon_path(),
		item_data.stack_max,
		item_data.description,
		item_data.buy_price,
		item_data.sell_price,
		item_data.get_need_effect_path(),
		item_data.can_discard,
		item_data.can_transfer
	) == true


func _get_inventory_item_amount(category_id: StringName, item_id: StringName) -> int:
	if _inventory_module == null or not _inventory_module.has_method("get_items"):
		return 0
	var entries_value: Variant = _inventory_module.call("get_items", category_id)
	if not (entries_value is Array):
		return 0
	var entries: Array = entries_value
	var total := 0
	for entry in entries:
		if entry is Dictionary and entry.get("id", &"") == item_id:
			total += int(entry.get("amount", 0))
	return total


func _get_craft_duration_seconds() -> float:
	var minutes := maxi(_recipe.craft_game_minutes, 1) * maxi(_quantity, 1)
	var real_seconds_per_game_minute := 1.0
	if _clock != null:
		real_seconds_per_game_minute = maxf(_clock.real_seconds_per_game_minute, 0.01)
	return float(minutes) * real_seconds_per_game_minute


func _record_bill_usage_for_completed_craft(recipe: CraftRecipeData, quantity: int, output_amount: int) -> void:
	if recipe == null:
		return
	if recipe.category_id == COOKING_CATEGORY_ID:
		_record_bill_electricity_usage(maxi(recipe.craft_game_minutes, 1) * maxi(quantity, 1), "cooking")
	if recipe.recipe_id == &"drink_0001_water_bottle":
		_record_bill_water_usage(maxi(output_amount, 1), "craft_water")


func _record_bill_water_usage(units: int, reason: String) -> void:
	var bill_system := get_node_or_null("/root/BillSystem")
	if bill_system == null:
		bill_system = get_tree().get_first_node_in_group(&"bill_system")
	if bill_system == null or not bill_system.has_method("record_water_usage"):
		return
	bill_system.call("record_water_usage", units, reason)


func _record_bill_electricity_usage(units: int, reason: String) -> void:
	var bill_system := get_node_or_null("/root/BillSystem")
	if bill_system == null:
		bill_system = get_tree().get_first_node_in_group(&"bill_system")
	if bill_system == null or not bill_system.has_method("record_electricity_usage"):
		return
	bill_system.call("record_electricity_usage", units, reason)


func _find_required_furniture(required_ids: PackedStringArray) -> Node2D:
	if _furniture_root == null:
		return null
	var nearest: Node2D = null
	var nearest_distance := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _required_ids_has(required_ids, _get_furniture_id(furniture)):
			continue
		var use_cell := _get_furniture_use_cell(furniture)
		if use_cell == INVALID_GRID_POSITION:
			continue
		var distance := _body.global_position.distance_squared_to(_room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint()))
		if nearest == null or distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
	return nearest


func _required_ids_has(required_ids: PackedStringArray, furniture_id: StringName) -> bool:
	for id_text in required_ids:
		if StringName(id_text) == furniture_id:
			return true
	return false


func _get_furniture_use_cell(furniture: Node2D) -> Vector2i:
	if furniture == null or _room_map == null or not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var furniture_cell: Vector2i = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	var furniture_footprint := _get_furniture_footprint(furniture)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_side_candidate_cells(furniture_cell, furniture_footprint, actor_footprint)
	var nearest := _get_nearest_furniture_use_candidate(candidates, actor_footprint, false)
	if nearest != INVALID_GRID_POSITION:
		return nearest
	return _get_nearest_furniture_use_candidate(candidates, actor_footprint, true)


func _get_nearest_furniture_use_candidate(candidates: Array[Vector2i], actor_footprint: Vector2i, allow_occupied: bool) -> Vector2i:
	var nearest := INVALID_GRID_POSITION
	var nearest_distance := INF
	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint, allow_occupied):
			continue
		var position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance := _body.global_position.distance_squared_to(position)
		if nearest == INVALID_GRID_POSITION or distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _get_side_candidate_cells(furniture_cell: Vector2i, furniture_footprint: Vector2i, actor_footprint: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.get_side_candidate_cells(furniture_cell, furniture_footprint, actor_footprint)


func _get_grid_path_velocity_to_target(target_cell: Vector2i) -> Vector2:
	if _body == null or _room_map == null:
		return Vector2.ZERO
	if not _is_valid_grid_position(target_cell):
		return Vector2.ZERO

	var start_cell := _get_current_or_nearest_walkable_top_left_cell(true, true)
	if not _is_valid_grid_position(start_cell):
		return Vector2.ZERO

	if start_cell == target_cell:
		_path_cells.clear()
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var to_target := target_position - _body.global_position
		if to_target.length() > use_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
			return _facing_direction * walk_speed
		return Vector2.ZERO

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return Vector2.ZERO

	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_target_cell_inside(waypoint_cell, _get_actor_grid_footprint()):
			_path_cells.clear()
			return Vector2.ZERO

		var waypoint_position := _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > use_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_waypoint)
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.find_grid_path_with_fallback(
		start_cell,
		target_cell,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_walkable"),
		Callable(self, "_is_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _get_current_or_nearest_walkable_top_left_cell(allow_snap: bool, allow_occupied: bool = false) -> Vector2i:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_target_cell_walkable(current_cell, _get_actor_grid_footprint()):
		return current_cell
	if allow_occupied and _is_target_cell_inside(current_cell, _get_actor_grid_footprint()):
		return current_cell

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if allow_snap and _is_valid_grid_position(nearest_cell):
		_body.global_position = _room_map.grid_to_world_area_center(nearest_cell, _get_actor_grid_footprint())
		_path_cells.clear()
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	if _room_map == null or _body == null:
		return INVALID_GRID_POSITION
	return AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
		_room_map,
		_body.global_position,
		_get_actor_grid_footprint(),
		INVALID_GRID_POSITION
	)


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	if _room_map == null:
		return INVALID_GRID_POSITION
	var nearest_cell := AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_walkable"),
		INVALID_GRID_POSITION
	)
	if _is_valid_grid_position(nearest_cell):
		return nearest_cell
	return AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _get_target_position() -> Vector2:
	if _target_cell != INVALID_GRID_POSITION and _room_map != null:
		return _room_map.grid_to_world_area_center(_target_cell, _get_actor_grid_footprint())
	if _target_furniture != null:
		return _target_furniture.global_position
	return _body.global_position


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i, allow_occupied: bool = false) -> bool:
	if not _is_target_cell_inside(cell, footprint):
		return false
	if allow_occupied:
		return true
	if _furniture_placement != null and _furniture_placement.has_method("can_place_at"):
		return _furniture_placement.call("can_place_at", cell, footprint) == true
	return true


func _is_target_cell_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	return _room_map.is_grid_area_inside(cell, footprint)


func _get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if furniture != null and furniture.has_meta("grid_footprint"):
		return furniture.get_meta("grid_footprint", Vector2i(1, 1))
	return Vector2i(1, 1)


func _get_actor_grid_footprint() -> Vector2i:
	return AICharacterGridMovementHelper.get_safe_footprint(actor_grid_footprint)


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return AICharacterGridMovementHelper.is_valid_grid_position(grid_position, INVALID_GRID_POSITION)


func _update_stuck(distance: float, delta: float) -> void:
	if distance < _last_distance - 0.5:
		_stuck_timer = 0.0
	else:
		_stuck_timer += maxf(delta, 0.0)
	_last_distance = distance


func _is_body_sleeping() -> bool:
	if _body == null:
		return false
	if not _body.has_method("is_sleeping"):
		return false
	return _body.call("is_sleeping") == true


func _add_skill_experience_for_completed_craft() -> void:
	if _skills_module == null or _recipe == null:
		return
	if _recipe.category_id != COOKING_CATEGORY_ID:
		return
	var gained_experience := maxi(_recipe.craft_game_minutes, 1) * maxi(_quantity, 1) * maxi(cooking_experience_per_game_minute, 1)
	_skills_module.add_skill_experience(AICharacterSkillsModule.SKILL_COOKING, gained_experience)


func _reset_action() -> void:
	_recipe = null
	_quantity = 1
	_target_furniture = null
	_target_cell = INVALID_GRID_POSITION
	_is_active = false
	_is_moving = false
	_is_crafting = false
	_action_progress_ratio = 0.0
	_craft_timer = 0.0
	_stuck_timer = 0.0
	_last_distance = INF
	_path_cells.clear()


func _get_furniture_id(node: Node) -> StringName:
	if node == null:
		return &""
	if node.has_meta("furniture_id"):
		return node.get_meta("furniture_id", &"") as StringName
	return &""


func _get_item_display_name(item_data: FoodItemData) -> String:
	if item_data == null:
		return ""
	if not item_data.display_name.is_empty():
		return item_data.display_name
	return String(item_data.item_id)


func _get_recipe_display_name(recipe: CraftRecipeData) -> String:
	if recipe == null or recipe.output_item == null:
		return ""
	if not recipe.output_item.display_name.is_empty():
		return recipe.output_item.display_name
	return String(recipe.recipe_id)


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log")
	if message_log != null and message_log.has_method("add_message"):
		message_log.call("add_message", message)


func _resolve_refs() -> void:
	if _inventory_module == null or not is_instance_valid(_inventory_module):
		_inventory_module = _get_inventory_module_from_path(inventory_module_path)
		if _inventory_module == null:
			_inventory_module = _get_inventory_module_from_path(legacy_inventory_module_path)
		if _inventory_module == null and _body != null:
			_inventory_module = InventoryLookup.get_inventory_module(_body)
	if _skills_module == null:
		_skills_module = get_node_or_null(skills_module_path) as AICharacterSkillsModule
	if _furniture_root == null:
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement == null:
		_furniture_placement = get_node_or_null(furniture_placement_module_path)
	if _room_map == null:
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("game_clock") as GameClockSystem


func _get_inventory_module_from_path(module_path: NodePath) -> Node:
	if module_path.is_empty():
		return null
	var module := get_node_or_null(module_path)
	if InventoryLookup.is_inventory_compatible(module):
		return module
	return null
