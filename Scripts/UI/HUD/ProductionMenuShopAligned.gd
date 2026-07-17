extends CraftMenu
class_name ProductionMenuShopAligned

const SHOP_ALIGNED_MENU_SIZE := Vector2(760.0, 760.0)
const SHOP_ALIGNED_OFFSET_LEFT := 580.0
const SHOP_ALIGNED_OFFSET_TOP := 80.0
const SHOP_ALIGNED_OFFSET_RIGHT := 1340.0
const SHOP_ALIGNED_OFFSET_BOTTOM := 840.0
const CRAFT_BEHAVIOR_NODE_NAME := "AICharacterCraftBehaviorModule"


func _apply_center_layout_after_parent() -> void:
	custom_minimum_size = SHOP_ALIGNED_MENU_SIZE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = SHOP_ALIGNED_OFFSET_LEFT
	offset_top = SHOP_ALIGNED_OFFSET_TOP
	offset_right = SHOP_ALIGNED_OFFSET_RIGHT
	offset_bottom = SHOP_ALIGNED_OFFSET_BOTTOM
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _request_craft_action(recipe: CraftRecipeData) -> bool:
	var actor := get_node_or_null(actor_path)
	if actor == null:
		return false
	var request_target := actor
	if not request_target.has_method("request_craft"):
		request_target = actor.get_node_or_null(CRAFT_BEHAVIOR_NODE_NAME)
	if request_target == null or not request_target.has_method("request_craft"):
		return false
	return request_target.call("request_craft", recipe, _craft_quantity) == true
