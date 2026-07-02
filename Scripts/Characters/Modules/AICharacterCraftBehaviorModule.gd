extends Node
class_name AICharacterCraftBehaviorModule

signal craft_started(recipe: CraftRecipeData, quantity: int)
signal craft_completed(recipe: CraftRecipeData, quantity: int)
signal craft_failed(message: String)

@export var inventory_module_path: NodePath = NodePath("../RobinInventoryModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var walk_speed: float = 80.0
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)

var _body: CharacterBody2D
var _is_active := false
var _action_progress_ratio := 0.0

func setup(body: CharacterBody2D) -> void:
	_body = body

func request_craft(recipe: CraftRecipeData, quantity: int) -> bool:
	if _is_active:
		return false
	if recipe == null:
		return false
	_is_active = true
	_action_progress_ratio = 0.0
	craft_started.emit(recipe, maxi(quantity, 1))
	return true

func is_active() -> bool:
	return _is_active

func is_action_progress_visible() -> bool:
	return _is_active

func get_action_progress_ratio() -> float:
	return clampf(_action_progress_ratio, 0.0, 1.0)

func is_action_item_display_visible() -> bool:
	return false

func get_action_item_icon_path() -> String:
	return ""

func get_facing_direction() -> Vector2:
	return Vector2.DOWN

func get_velocity(_delta: float) -> Vector2:
	return Vector2.ZERO
