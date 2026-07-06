extends PanelContainer
class_name MoveMenu

const DESTINATION_KIND_MAP: StringName = &"map"
const DESTINATION_KIND_EXPLORATION: StringName = &"exploration"
const MENU_MODE_MOVE: StringName = &"move"
const MENU_MODE_EXPLORE: StringName = &"explore"
const MAP_ID_ROBIN_ROOM: StringName = &"robin_room"
const MAP_ID_INFRASTRUCTURE_ROOM: StringName = &"infrastructure_room"
const MENU_SIZE := Vector2(760.0, 760.0)
const MENU_OFFSET_LEFT := 580.0
const MENU_OFFSET_TOP := 80.0
const MENU_OFFSET_RIGHT := 1340.0
const MENU_OFFSET_BOTTOM := 840.0

@export var robin_path: NodePath = NodePath("../../Robin")
@export var map_travel_module_path: NodePath = NodePath("../../MainSceneMapTravelModule")
@export var exploration_location_system_path: NodePath = NodePath("../../ExplorationLocationSystem")

@onready var rows: VBoxContainer = $MarginContainer/Rows
@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var action_list: VBoxContainer = $MarginContainer/Rows/ActionList
@onready var move_action_button: Button = $MarginContainer/Rows/ActionList/MoveActionButton
@onready var explore_action_button: Button = $MarginContainer/Rows/ActionList/ExploreActionButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _destination_buttons: Array[Button] = []
var _dynamic_controls: Array[Control] = []
var _duration_spin_box: SpinBox
var _book_library: Node
var _exploration_location_system: Node
var _menu_mode: StringName = MENU_MODE_MOVE
var _selected_exploration_minutes: int = 0


func _ready() -> void:
	visible = false
	_apply_shop_aligned_layout()
	if not is_in_group(&"move_menu"):
		add_to_group(&"move_menu")
	close_button.pressed.connect(close_menu)
	_configure_tab_buttons()
	_connect_book_library_signal()
	_refresh_content()


func open_menu() -> void:
	visible = true
	_menu_mode = MENU_MODE_MOVE
	_apply_shop_aligned_layout()
	_refresh_content()


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _configure_tab_buttons() -> void:
	if move_action_button != null:
		move_action_button.visible = true
		move_action_button.disabled = false
		move_action_button.toggle_mode = true
		move_action_button.text = "マップ移動"
		move_action_button.tooltip_text = "部屋マップ間の移動先を表示します。"
		if not move_action_button.pressed.is_connected(_on_move_action_pressed):
			move_action_button.pressed.connect(_on_move_action_pressed)
	if explore_action_button != null:
		explore_action_button.visible = true
		explore_action_button.disabled = false
		explore_action_button.toggle_mode = true
		explore_action_button.text = "探索"
		explore_action_button.tooltip_text = "解禁済みの探索ロケーションを表示します。"
		if not explore_action_button.pressed.is_connected(_on_explore_action_pressed):
			explore_action_button.pressed.connect(_on_explore_action_pressed)
	_sync_tab_button_state()


func _on_move_action_pressed() -> void:
	_menu_mode = MENU_MODE_MOVE
	_refresh_content()


func _on_explore_action_pressed() -> void:
	_menu_mode = MENU_MODE_EXPLORE
	_refresh_content()


func _sync_tab_button_state() -> void:
	if move_action_button != null:
		move_action_button.set_pressed_no_signal(_menu_mode == MENU_MODE_MOVE)
	if explore_action_button != null:
		explore_action_button.set_pressed_no_signal(_menu_mode == MENU_MODE_EXPLORE)


func _refresh_content() -> void:
	_clear_dynamic_controls()
	_sync_tab_button_state()
	_place_detail_label_under_title()
	if _menu_mode == MENU_MODE_EXPLORE:
		_show_exploration_tab()
		return
	_show_move_tab()


func _place_detail_label_under_title() -> void:
	if detail_label == null or rows == null:
		return
	var current_parent: Node = detail_label.get_parent()
	if current_parent != rows:
		if current_parent != null:
			current_parent.remove_child(detail_label)
		rows.add_child(detail_label)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target_index: int = 1
	var header: Control = rows.get_node_or_null("Header") as Control
	if header != null:
		target_index = header.get_index() + 1
	if detail_label.get_index() != target_index:
		rows.move_child(detail_label, target_index)


func _show_move_tab() -> void:
	title_label.text = "移動"
	var destinations: Array[Dictionary] = _get_move_destinations()
	var active_map_id: StringName = _get_active_map_id()
	for destination in destinations:
		var button: Button = _create_destination_button(destination, active_map_id)
		_add_dynamic_button(button)
	if visible:
		detail_label.text = "移動先を選んでください。探索は上の探索ボタンから開けます。"


func _show_exploration_tab() -> void:
	title_label.text = "探索"
	_add_dynamic_control(_create_exploration_message_card())
	_add_dynamic_control(_create_exploration_duration_row())
	var destinations: Array[Dictionary] = _get_exploration_destinations()
	var active_map_id: StringName = _get_active_map_id()
	for destination in destinations:
		var button: Button = _create_destination_button(destination, active_map_id)
		_add_dynamic_button(button)
	if visible:
		if destinations.is_empty():
			detail_label.text = "探索場所は電子書籍の購入で解禁されます。"
		else:
			detail_label.text = "探索時間を設定してから、探索場所を選んでください。"


func _create_exploration_message_card() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ExplorationMessageCard"
	panel.custom_minimum_size = Vector2(280.0, 96.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label: Label = Label.new()
	label.name = "MessageLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "探索メッセージカード\n探索は部屋マップへ移動せず、ロケーションカードに滞在します。一定間隔でイベントが起こり、今はアイテムが手に入ります。"
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	return panel


func _create_exploration_duration_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ExplorationDurationRow"
	row.custom_minimum_size = Vector2(280.0, 44.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = "探索時間"
	label.custom_minimum_size = Vector2(96.0, 32.0)
	row.add_child(label)

	_duration_spin_box = SpinBox.new()
	_duration_spin_box.name = "DurationSpinBox"
	_duration_spin_box.min_value = float(_get_exploration_min_duration_minutes())
	_duration_spin_box.max_value = float(_get_exploration_max_duration_minutes())
	_duration_spin_box.step = float(_get_exploration_duration_step_minutes())
	_duration_spin_box.value = float(_get_selected_exploration_minutes())
	_duration_spin_box.suffix = "分"
	_duration_spin_box.custom_minimum_size = Vector2(148.0, 32.0)
	_duration_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _duration_spin_box.value_changed.is_connected(_on_exploration_duration_changed):
		_duration_spin_box.value_changed.connect(_on_exploration_duration_changed)
	row.add_child(_duration_spin_box)
	return row


func _on_exploration_duration_changed(value: float) -> void:
	_selected_exploration_minutes = _get_exploration_safe_duration_minutes(roundi(value))


func _on_destination_button_pressed(destination: Dictionary) -> void:
	var target_id: StringName = _get_map_id_from_destination(destination)
	if target_id == &"":
		detail_label.text = "移動先データが壊れています。"
		return
	var destination_kind: StringName = _get_destination_kind(destination)
	if destination_kind == DESTINATION_KIND_EXPLORATION:
		_on_exploration_destination_pressed(destination)
		return
	_on_map_destination_pressed(destination)


func _on_map_destination_pressed(destination: Dictionary) -> void:
	var target_map_id: StringName = _get_map_id_from_destination(destination)
	if target_map_id == _get_active_map_id():
		detail_label.text = "すでに%sにいます。" % _get_destination_display_name(destination)
		_refresh_content()
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
	_refresh_content()


func _on_exploration_destination_pressed(destination: Dictionary) -> void:
	var location_id: StringName = _get_map_id_from_destination(destination)
	var system: Node = _get_exploration_location_system()
	if system == null or not system.has_method("request_exploration"):
		detail_label.text = "探索システムが見つかりません。"
		return
	var duration_minutes: int = _get_selected_exploration_minutes()
	var request_result: Variant = system.call("request_exploration", location_id, duration_minutes)
	if request_result == true:
		detail_label.text = "%sへ%d分の探索に向かいます。" % [_get_destination_display_name(destination), duration_minutes]
		close_menu()
		return
	detail_label.text = "今は探索へ出発できません: %s" % _get_destination_display_name(destination)
	_refresh_content()


func _add_dynamic_button(button: Button) -> void:
	_destination_buttons.append(button)
	_add_dynamic_control(button)


func _add_dynamic_control(control: Control) -> void:
	_dynamic_controls.append(control)
	action_list.add_child(control)


func _clear_dynamic_controls() -> void:
	for button in _destination_buttons:
		if button == null or not is_instance_valid(button):
			continue
	_destination_buttons.clear()
	for control in _dynamic_controls:
		if control == null or not is_instance_valid(control):
			continue
		var parent: Node = control.get_parent()
		if parent != null:
			parent.remove_child(control)
		control.queue_free()
	_dynamic_controls.clear()
	_duration_spin_box = null


func _create_destination_button(destination: Dictionary, active_map_id: StringName) -> Button:
	var target_id: StringName = _get_map_id_from_destination(destination)
	var display_name: String = _get_destination_display_name(destination)
	var description: String = String(destination.get("description", ""))
	var destination_kind: StringName = _get_destination_kind(destination)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(280.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	if destination_kind == DESTINATION_KIND_EXPLORATION:
		button.text = "%sを探索" % display_name
		button.disabled = false
	else:
		button.text = "%sへ移動" % display_name
		button.disabled = target_id == active_map_id
	button.tooltip_text = description
	button.pressed.connect(Callable(self, "_on_destination_button_pressed").bind(destination))
	return button


func _get_move_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	var added_map_ids: Dictionary = {}
	_add_destination(destinations, added_map_ids, MAP_ID_ROBIN_ROOM, "ロビンの部屋", "いつもの生活拠点へ戻ります。", DESTINATION_KIND_MAP)
	_add_destination(destinations, added_map_ids, MAP_ID_INFRASTRUCTURE_ROOM, "インフラルーム", "設備や都市インフラに近い管理区画へ移動します。", DESTINATION_KIND_MAP)
	return destinations


func _get_exploration_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	var added_map_ids: Dictionary = {}
	for destination in _get_book_unlocked_destinations():
		var map_id: StringName = _get_map_id_from_destination(destination)
		var display_name: String = String(destination.get("display_name", String(map_id)))
		var description: String = String(destination.get("description", ""))
		_add_destination(destinations, added_map_ids, map_id, display_name, description, DESTINATION_KIND_EXPLORATION)
	return destinations


func _add_destination(
	destinations: Array[Dictionary],
	added_map_ids: Dictionary,
	map_id: StringName,
	display_name: String,
	description: String = "",
	destination_kind: StringName = DESTINATION_KIND_MAP
) -> void:
	if map_id == &"" or added_map_ids.has(map_id):
		return
	added_map_ids[map_id] = true
	destinations.append({
		"map_id": map_id,
		"display_name": display_name,
		"description": description,
		"kind": destination_kind,
	})


func _get_book_unlocked_destinations() -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	var library: Node = _resolve_book_library()
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
	var robin: Node = _get_robin()
	if robin == null or not robin.has_method("request_entrance_travel"):
		return false

	var active_map: RoomMapGridModule = _get_active_map()
	var entrance: Node2D = _find_entrance_for_target(active_map, target_map_id)
	if entrance == null:
		return false

	return robin.call("request_entrance_travel", entrance, target_map_id) == true


func _try_direct_travel(target_map_id: StringName) -> bool:
	var travel_module: Node = _get_map_travel_module()
	if travel_module == null or not travel_module.has_method("travel_to_map"):
		return false
	travel_module.call("travel_to_map", target_map_id, true)
	return _get_active_map_id() == target_map_id


func _get_destination_kind(destination: Dictionary) -> StringName:
	var value: Variant = destination.get("kind", DESTINATION_KIND_MAP)
	if value is StringName:
		return value
	return StringName(String(value))


func _get_map_id_from_destination(destination: Dictionary) -> StringName:
	var value: Variant = destination.get("map_id", &"")
	if value is StringName:
		return value
	return StringName(String(value))


func _get_destination_display_name(destination: Dictionary) -> String:
	var display_name: String = String(destination.get("display_name", ""))
	if not display_name.is_empty():
		return display_name
	return _get_target_display_name(_get_map_id_from_destination(destination))


func _get_target_display_name(target_map_id: StringName) -> String:
	if target_map_id == MAP_ID_INFRASTRUCTURE_ROOM:
		return "インフラルーム"
	return "ロビンの部屋"


func _get_selected_exploration_minutes() -> int:
	if _selected_exploration_minutes <= 0:
		_selected_exploration_minutes = _get_exploration_default_duration_minutes()
	return _get_exploration_safe_duration_minutes(_selected_exploration_minutes)


func _get_exploration_default_duration_minutes() -> int:
	var system: Node = _get_exploration_location_system()
	if system != null and system.has_method("get_default_duration_minutes"):
		return int(system.call("get_default_duration_minutes"))
	return 180


func _get_exploration_min_duration_minutes() -> int:
	var system: Node = _get_exploration_location_system()
	if system != null and system.has_method("get_min_duration_minutes"):
		return int(system.call("get_min_duration_minutes"))
	return 30


func _get_exploration_max_duration_minutes() -> int:
	var system: Node = _get_exploration_location_system()
	if system != null and system.has_method("get_max_duration_minutes"):
		return int(system.call("get_max_duration_minutes"))
	return 720


func _get_exploration_duration_step_minutes() -> int:
	var system: Node = _get_exploration_location_system()
	if system != null and system.has_method("get_duration_step_minutes"):
		return int(system.call("get_duration_step_minutes"))
	return 30


func _get_exploration_safe_duration_minutes(minutes: int) -> int:
	var system: Node = _get_exploration_location_system()
	if system != null and system.has_method("get_safe_duration_minutes"):
		return int(system.call("get_safe_duration_minutes", minutes))
	return clampi(minutes, 30, 720)


func _get_active_map_id() -> StringName:
	var travel_module: Node = _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map_id"):
		var active_map_id_value: Variant = travel_module.call("get_active_map_id")
		if active_map_id_value is StringName:
			return active_map_id_value
		if active_map_id_value is String:
			return StringName(active_map_id_value)
	return MAP_ID_ROBIN_ROOM


func _get_active_map() -> RoomMapGridModule:
	var travel_module: Node = _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map"):
		return travel_module.call("get_active_map") as RoomMapGridModule
	return null


func _find_entrance_for_target(active_map: RoomMapGridModule, target_map_id: StringName) -> Node2D:
	if active_map == null:
		return null
	var furniture_root: Node2D = active_map.get_node_or_null("FurnitureRoot") as Node2D
	if furniture_root == null:
		return null
	for child in furniture_root.get_children():
		var furniture: Node2D = child as Node2D
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
	var robin: Node = get_node_or_null(robin_path)
	if robin != null:
		return robin
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("Robin")


func _get_map_travel_module() -> Node:
	var travel_module: Node = get_node_or_null(map_travel_module_path)
	if travel_module != null:
		return travel_module
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("MainSceneMapTravelModule")


func _get_exploration_location_system() -> Node:
	if _exploration_location_system != null and is_instance_valid(_exploration_location_system):
		return _exploration_location_system
	if not exploration_location_system_path.is_empty():
		_exploration_location_system = get_node_or_null(exploration_location_system_path)
		if _exploration_location_system != null:
			return _exploration_location_system
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	_exploration_location_system = scene_root.get_node_or_null("ExplorationLocationSystem")
	return _exploration_location_system


func _connect_book_library_signal() -> void:
	var library: Node = _resolve_book_library()
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
		_refresh_content()


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
