extends Node
class_name AICharacterCraftBehaviorModule

signal craft_started(recipe: CraftRecipeData, quantity: int)
signal craft_completed(recipe: CraftRecipeData, quantity: int)
signal craft_failed(message: String)

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const MOVE_PROGRESS_PORTION := 0.35

@export var inventory_module_path: NodePath = NodePath("../RobinInventoryModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var walk_speed: float = 80.0
@export var use_distance: float = 16.0
@export var stuck_warp_seconds: float = 1.25
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)

var _body: CharacterBody2D
var _inventory_module: RobinInventoryModule
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


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	_resolve_refs()
	if _is_active:
		_push_message("制作中です。")
		return false
	if recipe == null or recipe.output_item == null or _inventory_module == null:
		return false
	_recipe = recipe
	_quantity = maxi(quantity, 1)
	_action_progress_ratio = 0.0
	_craft_timer = 0.0
	_stuck_timer = 0.0
	_last_distance = INF
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
	return _is_active


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
	_action_progress_ratio = MOVE_PROGRESS_PORTION * clampf(1.0 - distance / 240.0, 0.0, 1.0)
	if distance <= use_distance:
		_begin_crafting()
		return Vector2.ZERO
	if _stuck_timer >= stuck_warp_seconds:
		_body.global_position = target_position
		_begin_crafting()
		return Vector2.ZERO
	_facing_direction = to_target.normalized()
	return _facing_direction * walk_speed


func _begin_crafting() -> void:
	_is_active = true
	_is_moving = false
	_is_crafting = true
	_craft_timer = 0.0
	_action_progress_ratio = MOVE_PROGRESS_PORTION
	_craft_duration_seconds = _get_craft_duration_seconds()
	if _target_furniture != null:
		var to_furniture := _target_furniture.global_position - _body.global_position
		if to_furniture.length() > 0.1:
			_facing_direction = to_furniture.normalized()


func _update_crafting(delta: float) -> void:
	if _clock != null and (not _clock.is_running or _clock.is_clock_paused):
		return
	var duration := maxf(_craft_duration_seconds, 0.1)
	_craft_timer = minf(_craft_timer + maxf(delta, 0.0), duration)
	var local_ratio := clampf(_craft_timer / duration, 0.0, 1.0)
	_action_progress_ratio = lerpf(MOVE_PROGRESS_PORTION, 1.0, local_ratio)
	if _craft_timer >= duration:
		_complete_crafting()


func _complete_crafting() -> void:
	if _recipe == null or _recipe.output_item == null or _inventory_module == null:
		_reset_action()
		return
	var output_amount := _recipe.output_amount * _quantity
	if not _inventory_module.add_food_item(_recipe.output_item, output_amount):
		_refund_ingredients()
		_push_message("完成品を追加できませんでした。")
		_reset_action()
		return
	_push_message("%s x%dを作りました。" % [_get_recipe_display_name(_recipe), output_amount])
	craft_completed.emit(_recipe, _quantity)
	_reset_action()


func _consume_ingredients() -> bool:
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
		_inventory_module.remove_item(ingredient.item_data.category_id, ingredient.item_data.item_id, ingredient.amount * _quantity)
	return true


func _refund_ingredients() -> void:
	if _recipe == null or _inventory_module == null:
		return
	for ingredient in _recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		_inventory_module.add_food_item(ingredient.item_data, ingredient.amount * _quantity)


func _get_inventory_item_amount(category_id: StringName, item_id: StringName) -> int:
	var total := 0
	for entry in _inventory_module.get_items(category_id):
		if entry is Dictionary and entry.get("id", &"") == item_id:
			total += int(entry.get("amount", 0))
	return total


func _get_craft_duration_seconds() -> float:
	var minutes := maxi(_recipe.craft_game_minutes, 1) * maxi(_quantity, 1)
	var real_seconds_per_game_minute := 1.0
	if _clock != null:
		real_seconds_per_game_minute = maxf(_clock.real_seconds_per_game_minute, 0.01)
	return float(minutes) * real_seconds_per_game_minute


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
	var nearest := INVALID_GRID_POSITION
	var nearest_distance := INF
	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint):
			continue
		var position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance := _body.global_position.distance_squared_to(position)
		if nearest == INVALID_GRID_POSITION or distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _get_side_candidate_cells(furniture_cell: Vector2i, furniture_footprint: Vector2i, actor_footprint: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in range(furniture_cell.y - actor_footprint.y + 1, furniture_cell.y + furniture_footprint.y):
		candidates.append(Vector2i(furniture_cell.x - actor_footprint.x, y))
		candidates.append(Vector2i(furniture_cell.x + furniture_footprint.x, y))
	for x in range(furniture_cell.x - actor_footprint.x + 1, furniture_cell.x + furniture_footprint.x):
		candidates.append(Vector2i(x, furniture_cell.y - actor_footprint.y))
		candidates.append(Vector2i(x, furniture_cell.y + furniture_footprint.y))
	return candidates


func _get_target_position() -> Vector2:
	if _target_cell != INVALID_GRID_POSITION and _room_map != null:
		return _room_map.grid_to_world_area_center(_target_cell, _get_actor_grid_footprint())
	if _target_furniture != null:
		return _target_furniture.global_position
	return _body.global_position


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null or not _room_map.is_grid_area_inside(cell, footprint):
		return false
	if _furniture_placement != null and _furniture_placement.has_method("can_place_at"):
		return _furniture_placement.call("can_place_at", cell, footprint) == true
	return true


func _get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if furniture != null and furniture.has_meta("grid_footprint"):
		return furniture.get_meta("grid_footprint", Vector2i(1, 1))
	return Vector2i(1, 1)


func _get_actor_grid_footprint() -> Vector2i:
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _update_stuck(distance: float, delta: float) -> void:
	if distance < _last_distance - 0.5:
		_stuck_timer = 0.0
	else:
		_stuck_timer += maxf(delta, 0.0)
	_last_distance = distance


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
	if _inventory_module == null:
		_inventory_module = get_node_or_null(inventory_module_path) as RobinInventoryModule
	if _furniture_root == null:
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement == null:
		_furniture_placement = get_node_or_null(furniture_placement_module_path)
	if _room_map == null:
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("game_clock") as GameClockSystem
