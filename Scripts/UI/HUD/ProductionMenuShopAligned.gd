extends CraftMenu
class_name ProductionMenuShopAligned

const SHOP_ALIGNED_MENU_SIZE := Vector2(760.0, 760.0)
const SHOP_ALIGNED_OFFSET_LEFT := 580.0
const SHOP_ALIGNED_OFFSET_TOP := 80.0
const SHOP_ALIGNED_OFFSET_RIGHT := 1340.0
const SHOP_ALIGNED_OFFSET_BOTTOM := 840.0


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
