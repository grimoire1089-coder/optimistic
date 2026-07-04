extends PanelContainer
class_name MoveMenu

const MAP_ID_ROBIN_ROOM: StringName = &"robin_room"
const MAP_ID_INFRASTRUCTURE_ROOM: StringName = &"infrastructure_room"
const MENU_SIZE := Vector2(760.0, 760.0)
const MENU_OFFSET_LEFT := 580.0
const MENU_OFFSET_TOP := 80.0
const MENU_OFFSET_RIGHT := 1340.0
const MENU_OFFSET_BOTTOM := 840.0

@export var robin_path: NodePath = NodePath("../../Robin")
@export var map_travel_module_path: NodePath = NodePath("../../MainSceneMapTravelModule")

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var action_list: VBoxContainer = $MarginContainer/Rows/ActionList
@onready var move_action_button: Button = $MarginContainer/Rows/ActionList/MoveActionButton
@onready var explore_action_button: Button = $MarginContainer/Rows/ActionList/ExploreActionButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel


func _ready() -> void:
	visible = false
	_apply_shop_aligned_layout()
	if not is_in_group(&"move_menu"):
		add_to_group(&"move_menu")
	close_button.pressed.connect(close_menu)
	move_action_button.pressed.connect(_on_move_action_pressed)
	explore_action_button.pressed.connect(_on_explore_action_pressed)
	_refresh_move_action_button()


func open_menu() -> void:
	visible = true
	_apply_shop_aligned_layout()
	_refresh_move_action_button()
	detail_label.text = "移動または探索を選んでください。"


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _on_move_action_pressed() -> void:
	_refresh_move_action_button()
	var robin := _get_robin()
	if robin == null or not robin.has_method("request_entrance_travel"):
		detail_label.text = "ロビンの移動処理が見つかりません。"
		return

	var target_map_id := _get_next_target_map_id()
	var active_map := _get_active_map()
	var entrance := _find_entrance_for_target(active_map, target_map_id)
	if entrance == null:
		detail_label.text = "移動先につながるエントランスが見つかりません。"
		return

	if robin.call("request_entrance_travel", entrance, target_map_id) == true:
		detail_label.text = "%sへ移動中です。" % _get_target_display_name(target_map_id)
		close_menu()
		return

	detail_label.text = "今は移動できません。"


func _on_explore_action_pressed() -> void:
	detail_label.text = "探索はまだ準備中です。"


func _refresh_move_action_button() -> void:
	if move_action_button == null:
		return
	move_action_button.text = "%sへ移動" % _get_target_display_name(_get_next_target_map_id())


func _get_next_target_map_id() -> StringName:
	var active_map_id := _get_active_map_id()
	if active_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return MAP_ID_ROBIN_ROOM
	return MAP_ID_INFRASTRUCTURE_ROOM


func _get_target_display_name(target_map_id: StringName) -> String:
	if target_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return "インフラルーム"
	return "ロビンの部屋"


func _get_active_map_id() -> StringName:
	var travel_module := _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map_id"):
		return travel_module.call("get_active_map_id") as StringName
	return MAP_ID_ROBIN_ROOM


func _get_active_map() -> RoomMapGridModule:
	var travel_module := _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map"):
		return travel_module.call("get_active_map") as RoomMapGridModule
	return null


func _find_entrance_for_target(active_map: RoomMapGridModule, target_map_id: StringName) -> Node2D:
	if active_map == null:
		return null
	var furniture_root := active_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return null
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_entrance_for_target(furniture, target_map_id):
			continue
		return furniture
	return null


func _is_entrance_for_target(furniture: Node2D, target_map_id: StringName) -> bool:
	if furniture is EntranceFurniture:
		return (furniture as EntranceFurniture).target_map_id == target_map_id
	if furniture.has_method("get"):
		var target_value: Variant = furniture.get("target_map_id")
		if target_value is StringName:
			return target_value == target_map_id
		if target_value is String:
			return StringName(target_value) == target_map_id
	return false


func _get_robin() -> Node:
	var robin := get_node_or_null(robin_path)
	if robin != null:
		return robin
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("Robin")


func _get_map_travel_module() -> Node:
	var travel_module := get_node_or_null(map_travel_module_path)
	if travel_module != null:
		return travel_module
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("MainSceneMapTravelModule")


func _apply_shop_aligned_layout() -> void:
	custom_minimum_size = MENU_SIZE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = MENU_OFFSET_LEFT
	offset_top = MENU_OFFSET_TOP
	offset_right = MENU_OFFSET_RIGHT
	offset_bottom = MENU_OFFSET_BOTTOM
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
