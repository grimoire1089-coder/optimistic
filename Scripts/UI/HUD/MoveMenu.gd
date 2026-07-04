extends PanelContainer
class_name MoveMenu

const MAP_ID_ROBIN_ROOM: StringName = &"robin_room"
const MAP_ID_INFRASTRUCTURE_ROOM: StringName = &"infrastructure_room"
const MAP_ID_CAPSULE_FARM_MUSHROOM_DISTRICT: StringName = &"capsule_farm_mushroom_district"
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

var _destination_buttons: Array[Button] = []
var _book_library: Node


func _ready() -> void:
	visible = false
	_apply_shop_aligned_layout()
	if not is_in_group(&"move_menu"):
		add_to_group(&"move_menu")
	close_button.pressed.connect(close_menu)
	if move_action_button != null:
		move_action_button.visible = false
		move_action_button.disabled = true
	explore_action_button.pressed.connect(_on_explore_action_pressed)
	_connect_book_library_signal()
	_refresh_destination_buttons()


func open_menu() -> void:
	visible = true
	_apply_shop_aligned_layout()
	_refresh_destination_buttons()
	detail_label.text = "移動または探索を選んでください。"


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _on_destination_button_pressed(destination: Dictionary) -> void:
	var target_map_id := _get_map_id_from_destination(destination)
	if target_map_id == &"":
		detail_label.text = "移動先データが壊れています。"
		return
	if target_map_id == _get_active_map_id():
		detail_label.text = "すでに%sにいます。" % _get_destination_display_name(destination)
		_refresh_destination_buttons()
		return

	if _try_entrance_travel(target_map_id):
		detail_label.text = "%sへ移動中です。" % _get_destination_display_name(destination)
		close_menu()
		return

	if _try_direct_travel(target_map_id):
		detail_label.text = "%sへ移動しました。" % _get_destination_display_name(destination)
		close_menu()
		return

	detail_label.text = "移動先のマップがまだ準備できていません: %s" % _get_destination_display_name(destination)
	_refresh_destination_buttons()


func _on_explore_action_pressed() -> void:
	detail_label.text = "探索はまだ準備中です。"


func _refresh_destination_buttons() -> void:
	_clear_destination_buttons()
	var destinations := _get_available_destinations()
	var active_map_id := _get_active_map_id()

	for destination in destinations:
		var button := _create_destination_button(destination, active_map_id)
		_destination_buttons.append(button)
		action_list.add_child(button)
		if explore_action_button != null:
			action_list.move_child(button, maxi(action_list.get_child_count() - 2, 0))

	if visible:
		if destinations.is_empty():
			detail_label.text = "現在選べる移動先がありません。"
		else:
			detail_label.text = "移動先を選んでください。"


func _clear_destination_buttons() -> void:
	for button in _destination_buttons:
		if button == null or not is_instance_valid(button):
			continue
		var parent := button.get_parent()
		if parent != null:
			parent.remove_child(button)
		button.queue_free()
	_destination_buttons.clear()


func _create_destination_button(destination: Dictionary, active_map_id: StringName) -> Button:
	var target_map_id := _get_map_id_from_destination(destination)
	var display_name := _get_destination_display_name(destination)
	var description := String(destination.get("description", ""))

	var button := Button.new()
	button.custom_minimum_size = Vector2(280, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%sへ移動" % display_name
	button.tooltip_text = description
	button.disabled = target_map_id == active_map_id
	button.pressed.connect(Callable(self, "_on_destination_button_pressed").bind(destination))
	return button


func _get_available_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	var added_map_ids := {}

	_add_destination(
		destinations,
		added_map_ids,
		MAP_ID_ROBIN_ROOM,
		"ロビンの部屋",
		"いつもの生活拠点へ戻ります。"
	)
	_add_destination(
		destinations,
		added_map_ids,
		MAP_ID_INFRASTRUCTURE_ROOM,
		"インフラルーム",
		"設備や都市インフラに近い管理区画へ移動します。"
	)

	for destination in _get_book_unlocked_destinations():
		var map_id := _get_map_id_from_destination(destination)
		var display_name := String(destination.get("display_name", String(map_id)))
		var description := String(destination.get("description", ""))
		_add_destination(destinations, added_map_ids, map_id, display_name, description)

	return destinations


func _add_destination(
	destinations: Array[Dictionary],
	added_map_ids: Dictionary,
	map_id: StringName,
	display_name: String,
	description: String = ""
) -> void:
	if map_id == &"" or added_map_ids.has(map_id):
		return
	added_map_ids[map_id] = true
	destinations.append({
		"map_id": map_id,
		"display_name": display_name,
		"description": description,
	})


func _get_book_unlocked_destinations() -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	var library := _resolve_book_library()
	if library == null or not library.has_method("get_unlocked_travel_destinations"):
		return empty
	var value: Variant = library.call("get_unlocked_travel_destinations")
	if value is Array:
		var destinations: Array[Dictionary] = []
		for raw_destination in value:
			if raw_destination is Dictionary:
				destinations.append(raw_destination)
		return destinations
	return empty


func _try_entrance_travel(target_map_id: StringName) -> bool:
	var robin := _get_robin()
	if robin == null or not robin.has_method("request_entrance_travel"):
		return false

	var active_map := _get_active_map()
	var entrance := _find_entrance_for_target(active_map, target_map_id)
	if entrance == null:
		return false

	return robin.call("request_entrance_travel", entrance, target_map_id) == true


func _try_direct_travel(target_map_id: StringName) -> bool:
	var travel_module := _get_map_travel_module()
	if travel_module == null or not travel_module.has_method("travel_to_map"):
		return false
	travel_module.call("travel_to_map", target_map_id, true)
	return _get_active_map_id() == target_map_id


func _get_map_id_from_destination(destination: Dictionary) -> StringName:
	var value: Variant = destination.get("map_id", &"")
	if value is StringName:
		return value
	return StringName(String(value))


func _get_destination_display_name(destination: Dictionary) -> String:
	var display_name := String(destination.get("display_name", ""))
	if not display_name.is_empty():
		return display_name
	return _get_target_display_name(_get_map_id_from_destination(destination))


func _get_target_display_name(target_map_id: StringName) -> String:
	if target_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return "インフラルーム"
	if target_map_id == MAP_ID_CAPSULE_FARM_MUSHROOM_DISTRICT:
		return "カプセルファーム きのこ採取地区"
	return "ロビンの部屋"


func _get_active_map_id() -> StringName:
	var travel_module := _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map_id"):
		var active_map_id_value: Variant = travel_module.call("get_active_map_id")
		if active_map_id_value is StringName:
			return active_map_id_value
		if active_map_id_value is String:
			return StringName(active_map_id_value)
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


func _connect_book_library_signal() -> void:
	var library := _resolve_book_library()
	if library == null:
		return
	var callable := Callable(self, "_on_book_library_changed")
	if not library.is_connected("library_changed", callable):
		library.connect("library_changed", callable)


func _resolve_book_library() -> Node:
	if _book_library != null and is_instance_valid(_book_library):
		return _book_library
	_book_library = get_node_or_null("/root/BookLibrary")
	return _book_library


func _on_book_library_changed() -> void:
	if visible:
		_refresh_destination_buttons()


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
