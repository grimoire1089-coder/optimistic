extends Node
class_name AICharacterActionItemDisplayModule

@export var hydrate_behavior_path: NodePath = NodePath("../AICharacterHydrateBehaviorModule")
@export var craft_behavior_path: NodePath = NodePath("../AICharacterCraftBehaviorModule")
@export var sit_behavior_path: NodePath = NodePath("../AICharacterSitBehaviorModule")
@export var read_book_behavior_path: NodePath = NodePath("../AICharacterReadBookBehaviorModule")
@export var item_center_offset: Vector2 = Vector2(0.0, -18.0)
@export var item_display_size: Vector2 = Vector2(70.0, 70.0)
@export var item_z_index: int = 190
@export var snap_standing_lapis_to_grid: bool = true
@export var update_interval_seconds: float = 0.1
@export var idle_check_interval_seconds: float = 0.35

var _body: Node2D
var _hydrate_behavior: Node
var _craft_behavior: Node
var _sit_behavior: Node
var _read_book_behavior: Node
var _item_rect: TextureRect
var _display_add_deferred := false
var _current_icon_path := ""
var _was_standing_lapis := false
var _update_timer: Timer
var _explicit_item_visible := false
var _explicit_icon_path := ""
var _explicit_global_center: Variant = null
var _explicit_item_owner_ref: WeakRef
var _explicit_item_has_owner := false


func _ready() -> void:
	_body = get_parent() as Node2D
	_resolve_refs()
	_was_standing_lapis = _is_standing_lapis_active()
	_request_display()
	_ensure_update_timer()
	_update_timer.start()


func setup(body: Node2D) -> void:
	_body = body
	_resolve_refs()
	_was_standing_lapis = _is_standing_lapis_active()
	_request_display()
	_ensure_update_timer()
	if _update_timer != null and _update_timer.is_stopped():
		_update_timer.start()


func show_item_icon(icon_path: String, global_center: Variant = null, item_owner: Node = null) -> void:
	var display_owner := item_owner
	if display_owner == null:
		display_owner = _get_active_item_source()
	_explicit_item_visible = not icon_path.is_empty()
	_explicit_icon_path = icon_path
	_explicit_global_center = global_center
	_set_explicit_item_owner(display_owner)
	_request_display()
	_apply_explicit_item_icon()
	_sync_update_timer_interval()


func clear_item_icon(item_owner: Node = null) -> void:
	if not _can_clear_explicit_item(item_owner):
		return
	_clear_explicit_item_state()
	_hide_item_rect()
	_sync_update_timer_interval()


func refresh_action_item_display() -> void:
	_resolve_refs()
	_snap_lapis_position_if_needed()
	_request_display()
	_update_display()
	_sync_update_timer_interval()


func _on_update_timer_timeout() -> void:
	refresh_action_item_display()


func _get_next_update_interval() -> float:
	if _explicit_item_visible:
		return update_interval_seconds if _explicit_item_has_owner else idle_check_interval_seconds
	if _get_active_item_source() != null:
		return update_interval_seconds
	if _is_standing_lapis_active() or _was_standing_lapis:
		return update_interval_seconds
	return idle_check_interval_seconds


func _update_display() -> void:
	if _item_rect == null or not is_instance_valid(_item_rect):
		return
	if _explicit_item_visible:
		if _explicit_item_has_owner and not _is_explicit_item_owner_active():
			_clear_explicit_item_state()
			_hide_item_rect()
			return
		_apply_explicit_item_icon()
		return
	var source := _get_active_item_source()
	if source == null:
		_item_rect.visible = false
		_current_icon_path = ""
		return

	var icon_path := ""
	if source.has_method("get_action_item_icon_path"):
		icon_path = String(source.call("get_action_item_icon_path"))
	if icon_path == "":
		_item_rect.visible = false
		_current_icon_path = ""
		return

	if icon_path != _current_icon_path:
		_current_icon_path = icon_path
		_item_rect.texture = _load_icon(icon_path)

	_item_rect.visible = _item_rect.texture != null
	_item_rect.size = item_display_size
	_update_item_rect_position(source)


func _apply_explicit_item_icon() -> void:
	if _item_rect == null or not is_instance_valid(_item_rect):
		return
	if not _explicit_item_visible or _explicit_icon_path.is_empty():
		_item_rect.visible = false
		return
	if _explicit_icon_path != _current_icon_path:
		_current_icon_path = _explicit_icon_path
		_item_rect.texture = _load_icon(_explicit_icon_path)
	_item_rect.visible = _item_rect.texture != null
	_item_rect.size = item_display_size
	if _explicit_global_center is Vector2:
		var center: Vector2 = _explicit_global_center
		_item_rect.global_position = center - item_display_size * 0.5
	else:
		_item_rect.position = item_center_offset - item_display_size * 0.5


func _set_explicit_item_owner(item_owner: Node) -> void:
	_explicit_item_has_owner = item_owner != null and is_instance_valid(item_owner)
	_explicit_item_owner_ref = weakref(item_owner) if _explicit_item_has_owner else null


func _get_explicit_item_owner() -> Node:
	if not _explicit_item_has_owner or _explicit_item_owner_ref == null:
		return null
	var item_owner := _explicit_item_owner_ref.get_ref() as Node
	if item_owner == null or not is_instance_valid(item_owner):
		return null
	return item_owner


func _is_explicit_item_owner_active() -> bool:
	var item_owner := _get_explicit_item_owner()
	if item_owner == null:
		return false
	if item_owner.has_method("is_action_item_display_visible"):
		return item_owner.call("is_action_item_display_visible") == true
	return item_owner.is_inside_tree()


func _can_clear_explicit_item(request_owner: Node) -> bool:
	if not _explicit_item_visible:
		return true
	if not _explicit_item_has_owner:
		return true
	var explicit_owner := _get_explicit_item_owner()
	if explicit_owner == null:
		return true
	if request_owner == null:
		return not _is_explicit_item_owner_active()
	return request_owner == explicit_owner


func _clear_explicit_item_state() -> void:
	_explicit_item_visible = false
	_explicit_icon_path = ""
	_explicit_global_center = null
	_explicit_item_owner_ref = null
	_explicit_item_has_owner = false
	_current_icon_path = ""


func _hide_item_rect() -> void:
	if _item_rect != null and is_instance_valid(_item_rect):
		_item_rect.visible = false


func _update_item_rect_position(source: Node) -> void:
	var dining_center: Variant = _get_dining_item_global_center(source)
	if dining_center is Vector2:
		var dining_center_position: Vector2 = dining_center
		_item_rect.global_position = dining_center_position - item_display_size * 0.5
		return
	_item_rect.position = item_center_offset - item_display_size * 0.5


func _get_dining_item_global_center(source: Node) -> Variant:
	if source == null or source != _hydrate_behavior:
		return null
	if not source.has_method("is_drinking"):
		return null
	if source.call("is_drinking") != true:
		return null
	if source.get("_dining_seat_used_for_current_drink") != true:
		return null

	var chair := source.get("_target_dining_seat") as Node2D
	var room_map := source.get("_room_map") as RoomMapGridModule
	var furniture_root := source.get("_furniture_root") as Node
	if chair == null or room_map == null or furniture_root == null:
		return null

	var tables: Array[Node2D] = []
	for child in furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if AICharacterDiningSeatHelper.is_table_furniture(furniture):
			tables.append(furniture)

	var minimum_overlap_cells := 2
	var source_minimum_overlap: Variant = source.get("dining_minimum_overlap_cells")
	if source_minimum_overlap is int:
		minimum_overlap_cells = int(source_minimum_overlap)
	var table := AICharacterDiningSeatHelper.find_connected_table_for_chair(chair, tables, minimum_overlap_cells)
	if table == null:
		return null

	return _get_table_side_overlap_center(room_map, chair, table)


func _get_table_side_overlap_center(room_map: RoomMapGridModule, chair: Node2D, table: Node2D) -> Variant:
	var chair_grid := AICharacterDiningSeatHelper.get_furniture_grid_position(chair)
	var chair_footprint := AICharacterDiningSeatHelper.get_furniture_footprint(chair)
	var table_grid := AICharacterDiningSeatHelper.get_furniture_grid_position(table)
	var table_footprint := AICharacterDiningSeatHelper.get_furniture_footprint(table)
	if not AICharacterDiningSeatHelper.is_valid_grid_position(chair_grid):
		return null
	if not AICharacterDiningSeatHelper.is_valid_grid_position(table_grid):
		return null

	var chair_left := chair_grid.x
	var chair_right := chair_grid.x + chair_footprint.x
	var chair_top := chair_grid.y
	var chair_bottom := chair_grid.y + chair_footprint.y
	var table_left := table_grid.x
	var table_right := table_grid.x + table_footprint.x
	var table_top := table_grid.y
	var table_bottom := table_grid.y + table_footprint.y

	if chair_right == table_left:
		return _get_grid_area_center_from_edges(room_map, table_left, maxi(chair_top, table_top), table_left + 1, mini(chair_bottom, table_bottom))
	if table_right == chair_left:
		return _get_grid_area_center_from_edges(room_map, table_right - 1, maxi(chair_top, table_top), table_right, mini(chair_bottom, table_bottom))
	if chair_bottom == table_top:
		return _get_grid_area_center_from_edges(room_map, maxi(chair_left, table_left), table_top, mini(chair_right, table_right), table_top + 1)
	if table_bottom == chair_top:
		return _get_grid_area_center_from_edges(room_map, maxi(chair_left, table_left), table_bottom - 1, mini(chair_right, table_right), table_bottom)
	return null


func _get_grid_area_center_from_edges(room_map: RoomMapGridModule, left: int, top: int, right: int, bottom: int) -> Variant:
	if room_map == null:
		return null
	if right <= left or bottom <= top:
		return null
	var grid_position := Vector2i(left, top)
	var footprint := Vector2i(right - left, bottom - top)
	if not room_map.is_grid_area_inside(grid_position, footprint):
		return null
	return room_map.grid_to_world_area_center(grid_position, footprint)


func _snap_lapis_position_if_needed() -> void:
	if not snap_standing_lapis_to_grid:
		_was_standing_lapis = false
		return
	var is_standing_lapis := _is_standing_lapis_active()
	if is_standing_lapis:
		_snap_body_to_grid()
	elif _was_standing_lapis:
		_snap_body_to_grid()
	_was_standing_lapis = is_standing_lapis


func _is_standing_lapis_active() -> bool:
	if _sit_behavior == null:
		return false
	if not _sit_behavior.has_method("is_using_lapis"):
		return false
	if _sit_behavior.call("is_using_lapis") != true:
		return false
	if _sit_behavior.has_method("is_sitting") and _sit_behavior.call("is_sitting") == true:
		return false
	return true


func _snap_body_to_grid() -> void:
	if _body == null:
		return
	if not _body.has_method("snap_to_nearest_walkable_grid"):
		return
	_body.call("snap_to_nearest_walkable_grid")


func _get_active_item_source() -> Node:
	if _craft_behavior != null and _should_show_source(_craft_behavior):
		return _craft_behavior
	if _hydrate_behavior != null and _should_show_source(_hydrate_behavior):
		return _hydrate_behavior
	if _read_book_behavior != null and _should_show_source(_read_book_behavior):
		return _read_book_behavior
	if _sit_behavior != null and _should_show_source(_sit_behavior):
		return _sit_behavior
	return null


func _should_show_source(source: Node) -> bool:
	if source == null:
		return false
	if not source.has_method("is_action_item_display_visible"):
		return false
	return source.call("is_action_item_display_visible") == true


func _load_icon(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _request_display() -> void:
	if _item_rect != null and is_instance_valid(_item_rect):
		return
	if _display_add_deferred:
		return
	if _body == null:
		return
	_display_add_deferred = true
	call_deferred("_ensure_display_deferred")


func _ensure_display_deferred() -> void:
	_display_add_deferred = false
	_resolve_refs()
	if _item_rect != null and is_instance_valid(_item_rect):
		return
	if _body == null or not is_instance_valid(_body):
		return

	_item_rect = TextureRect.new()
	_item_rect.name = "AIActionItemDisplay"
	_item_rect.custom_minimum_size = item_display_size
	_item_rect.size = item_display_size
	_item_rect.position = item_center_offset - item_display_size * 0.5
	_item_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_rect.visible = false
	_item_rect.z_index = item_z_index
	_item_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_item_rect)
	_apply_explicit_item_icon()


func _ensure_update_timer() -> void:
	if _update_timer != null and is_instance_valid(_update_timer):
		return
	_update_timer = Timer.new()
	_update_timer.name = "ActionItemDisplayUpdateTimer"
	_update_timer.one_shot = false
	_update_timer.autostart = false
	_update_timer.wait_time = maxf(idle_check_interval_seconds, 0.05)
	_update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(_update_timer)


func _sync_update_timer_interval() -> void:
	if _update_timer == null or not is_instance_valid(_update_timer):
		return
	var next_wait_time := maxf(_get_next_update_interval(), 0.05)
	if is_equal_approx(_update_timer.wait_time, next_wait_time):
		return
	_update_timer.wait_time = next_wait_time
	if not _update_timer.is_stopped():
		_update_timer.start()


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as Node2D
	if _hydrate_behavior == null and not hydrate_behavior_path.is_empty():
		_hydrate_behavior = get_node_or_null(hydrate_behavior_path)
	if _craft_behavior == null and not craft_behavior_path.is_empty():
		_craft_behavior = get_node_or_null(craft_behavior_path)
	if _sit_behavior == null and not sit_behavior_path.is_empty():
		_sit_behavior = get_node_or_null(sit_behavior_path)
	if _read_book_behavior == null and not read_book_behavior_path.is_empty():
		_read_book_behavior = get_node_or_null(read_book_behavior_path)
