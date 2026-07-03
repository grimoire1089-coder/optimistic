extends Node
class_name AICharacterReadBookBehaviorModule

signal reading_started(book: BookData)
signal reading_completed(book: BookData)
signal reading_interrupted(book: BookData)

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const BUILD_LOCK_META := &"build_locked_by_sleep"
const BUILD_LOCK_REASON_META := &"build_lock_reason"

@export var need_planner_path: NodePath = NodePath("../AICharacterNeedsBundle/NeedDrivenAIPlanner")
@export var skills_module_path: NodePath = NodePath("../AICharacterSkillsModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var idle_action_id: StringName = CharacterNeedActionIds.IDLE
@export var play_action_id: StringName = CharacterNeedActionIds.PLAY
@export var stool_ids: Array[StringName] = [&"stool"]
@export var walk_speed: float = 80.0
@export var arrive_distance: float = 12.0
@export var grid_arrival_distance: float = 6.0
@export var stuck_warp_seconds: float = 1.25
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var snap_to_stool_when_reading: bool = true
@export_range(0.1, 60.0, 0.1) var reading_game_minutes_per_page: float = 1.0

var _body: CharacterBody2D
var _need_planner: NeedDrivenAIPlanner
var _skills_module: AICharacterSkillsModule
var _furniture_root: Node
var _furniture_placement_module: Node
var _room_map: RoomMapGridModule
var _clock: GameClockSystem
var _book: BookData
var _target_stool: Node2D
var _reading_stool: Node2D
var _target_cell: Vector2i = INVALID_GRID_POSITION
var _path_cells: Array[Vector2i] = []
var _is_active := false
var _is_moving := false
var _is_reading := false
var _is_sitting := false
var _action_progress_ratio := 0.0
var _page_timer := 0.0
var _last_distance := INF
var _stuck_timer := 0.0
var _facing_direction := Vector2.DOWN


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func request_read_book(book: BookData) -> bool:
	_resolve_refs()
	if _is_active:
		_push_message("読書中です。")
		return false
	if _is_body_sleeping() or _is_body_working():
		_push_message("今は読書できません。")
		return false
	if book == null or not book.is_skill_book():
		return false
	if _should_interrupt_for_need():
		_push_message("今は欲求を優先します。")
		return false

	_book = book
	_is_active = true
	_is_moving = false
	_is_reading = false
	_is_sitting = false
	_action_progress_ratio = _get_book_progress_ratio()
	_page_timer = 0.0
	_last_distance = INF
	_stuck_timer = 0.0
	_path_cells.clear()
	_set_target_stool(_find_nearest_stool())

	if _target_stool != null and _is_valid_grid_position(_target_cell):
		_is_moving = true
	else:
		_begin_reading(false)

	_push_message("%sを読み始めます。" % _get_book_display_name(_book))
	reading_started.emit(_book)
	return true


func is_active() -> bool:
	return _is_active


func is_reading() -> bool:
	return _is_reading


func is_moving() -> bool:
	return _is_moving


func is_sitting() -> bool:
	return _is_sitting


func is_action_progress_visible() -> bool:
	return _is_reading


func get_action_progress_ratio() -> float:
	return clampf(_action_progress_ratio, 0.0, 1.0)


func is_action_item_display_visible() -> bool:
	return _is_reading and _book != null


func get_action_item_icon_path() -> String:
	if _book == null:
		return ""
	return _book.get_icon_path()


func get_facing_direction() -> Vector2:
	return _facing_direction


func cancel_reading() -> void:
	if not _is_active:
		return
	_interrupt_reading(false)


func debug_reset_action() -> void:
	_reset_action()


func get_debug_path_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _is_reading:
		return result
	for cell in _path_cells:
		result.append(cell)
	return result


func get_debug_target_cell() -> Vector2i:
	if _is_reading:
		return INVALID_GRID_POSITION
	return _target_cell


func get_debug_next_cell() -> Vector2i:
	if _is_reading or _path_cells.is_empty():
		return INVALID_GRID_POSITION
	return _path_cells[0]


func get_debug_movement_summary() -> String:
	if _is_reading:
		return "reading=true book=%s pages=%d/%d sitting=%s footprint=%s" % [
			String(_book.get_item_id()) if _book != null else "",
			_get_read_pages(),
			_get_page_count(),
			str(_is_sitting),
			str(_get_actor_grid_footprint()),
		]
	return "target_cell=%s next_cell=%s path=%d footprint=%s reading=%s" % [
		str(get_debug_target_cell()),
		str(get_debug_next_cell()),
		_path_cells.size(),
		str(_get_actor_grid_footprint()),
		str(_is_reading),
	]


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	if not _is_active:
		return Vector2.ZERO
	if _body == null or _book == null:
		_reset_action()
		return Vector2.ZERO
	if _should_interrupt_for_need():
		_interrupt_reading(true)
		return Vector2.ZERO
	if _is_reading:
		_update_reading(delta)
		return Vector2.ZERO
	if _is_moving:
		return _update_moving(delta)
	return Vector2.ZERO


func _update_moving(delta: float) -> Vector2:
	var target_position := _get_target_position()
	var to_target := target_position - _body.global_position
	var distance := to_target.length()
	_update_stuck(distance, delta)
	_action_progress_ratio = _get_book_progress_ratio()
	if distance <= arrive_distance:
		_begin_reading(true)
		return Vector2.ZERO
	if _stuck_timer >= stuck_warp_seconds:
		_body.global_position = target_position
		_begin_reading(true)
		return Vector2.ZERO
	var path_velocity := _get_grid_path_velocity_to_target(_target_cell)
	if path_velocity != Vector2.ZERO:
		return path_velocity
	if _target_stool != null:
		_clear_target()
		_begin_reading(false)
		return Vector2.ZERO
	_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
	return _facing_direction * walk_speed


func _begin_reading(sitting: bool) -> void:
	_is_active = true
	_is_moving = false
	_is_reading = true
	_is_sitting = sitting and _target_stool != null and is_instance_valid(_target_stool)
	_path_cells.clear()
	_page_timer = 0.0
	_action_progress_ratio = _get_book_progress_ratio()
	if _is_sitting:
		_set_reading_stool(_target_stool)
		_face_stool()
		if snap_to_stool_when_reading:
			_body.global_position = _get_stool_sit_position(_target_stool)
	else:
		_clear_reading_stool_lock()
		_snap_body_to_current_grid_center()
		_facing_direction = Vector2.DOWN


func _update_reading(delta: float) -> void:
	_action_progress_ratio = _get_book_progress_ratio()
	if _is_sitting:
		_face_stool()
	else:
		_facing_direction = Vector2.DOWN
	if _clock != null and (not _clock.is_running or _clock.is_clock_paused):
		return

	var seconds_per_page := _get_seconds_per_page()
	_page_timer += maxf(delta, 0.0)
	while _page_timer >= seconds_per_page and _is_active and _is_reading:
		_page_timer -= seconds_per_page
		_read_next_page()


func _read_next_page() -> void:
	if _book == null:
		_reset_action()
		return
	if _get_read_pages() >= _get_page_count():
		_complete_reading()
		return
	if _skills_module != null and _book.skill_id != &"" and _book.skill_experience_per_page > 0:
		_skills_module.add_skill_experience(_book.skill_id, _book.skill_experience_per_page)
	var library := _get_book_library()
	if library != null and library.has_method("add_read_pages"):
		library.call("add_read_pages", _book, 1)
	_action_progress_ratio = _get_book_progress_ratio()
	if _get_read_pages() >= _get_page_count():
		_complete_reading()


func _complete_reading() -> void:
	if _book == null:
		_reset_action()
		return
	var completed_book := _book
	var library := _get_book_library()
	if library != null and library.has_method("mark_book_completed"):
		library.call("mark_book_completed", completed_book)
	_apply_completion_bonus(completed_book)
	_push_message("%sを読破しました。" % _get_book_display_name(completed_book))
	reading_completed.emit(completed_book)
	_reset_action()


func _apply_completion_bonus(book: BookData) -> void:
	if _skills_module == null or book == null:
		return
	if book.completion_bonus_skill_id == &"":
		return
	if not _skills_module.has_method("apply_skill_experience_bonus"):
		return
	if _skills_module.call(
		"apply_skill_experience_bonus",
		book.completion_bonus_skill_id,
		book.completion_bonus_until_level,
		book.completion_bonus_multiplier,
		book.get_item_id()
	) == true:
		_push_message("料理経験値に読書ボーナスがつきました。")


func _interrupt_reading(show_message: bool) -> void:
	var interrupted_book := _book
	if show_message and interrupted_book != null:
		_push_message("%sの読書を中断しました。" % _get_book_display_name(interrupted_book))
	if interrupted_book != null:
		reading_interrupted.emit(interrupted_book)
	_reset_action()


func _reset_action() -> void:
	_clear_reading_stool_lock()
	_book = null
	_target_stool = null
	_target_cell = INVALID_GRID_POSITION
	_path_cells.clear()
	_is_active = false
	_is_moving = false
	_is_reading = false
	_is_sitting = false
	_action_progress_ratio = 0.0
	_page_timer = 0.0
	_last_distance = INF
	_stuck_timer = 0.0


func _should_interrupt_for_need() -> bool:
	var planned_action := _get_planned_action_id()
	return planned_action != idle_action_id and planned_action != play_action_id


func _get_planned_action_id() -> StringName:
	if _need_planner == null:
		return idle_action_id
	return _need_planner.get_next_action_id()


func _find_nearest_stool() -> Node2D:
	if _furniture_root == null or _body == null:
		return null

	var nearest: Node2D = null
	var nearest_score := INF
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var distance_map := _get_grid_distance_map(start_cell)
	var fallback_distance_map: Dictionary = {}
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_stool(furniture):
			continue
		var use_cell := _get_stool_use_cell_with_distance_map(furniture, distance_map)
		var score_distance_map := distance_map
		if not _is_valid_grid_position(use_cell):
			if fallback_distance_map.is_empty():
				fallback_distance_map = _get_grid_distance_map(start_cell, true)
			use_cell = _get_stool_use_cell_with_distance_map(furniture, fallback_distance_map, true)
			score_distance_map = fallback_distance_map
		if not _is_valid_grid_position(use_cell):
			continue
		var use_position := _get_stool_use_position(use_cell)
		var path_score := _get_grid_distance_score(score_distance_map, use_cell)
		if path_score < 0.0:
			continue
		var distance_score := _body.global_position.distance_squared_to(use_position) / 1000000.0
		var score := path_score + distance_score
		if nearest == null or score < nearest_score:
			nearest = furniture
			nearest_score = score
	return nearest


func _is_stool(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_be_sat_on") and furniture.call("can_be_sat_on") == true:
		return true
	if furniture.has_method("is_stool") and furniture.call("is_stool") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if stool_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if stool_ids.has(property_id):
			return true
	return false


func _set_target_stool(stool: Node2D) -> void:
	if stool == null:
		_clear_target()
		return
	_target_stool = stool
	_target_cell = _get_stool_use_cell(_target_stool)
	_path_cells.clear()


func _clear_target() -> void:
	_target_stool = null
	_target_cell = INVALID_GRID_POSITION
	_path_cells.clear()


func _get_stool_use_cell(stool: Node2D) -> Vector2i:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var use_cell := _get_stool_use_cell_with_distance_map(stool, _get_grid_distance_map(start_cell))
	if _is_valid_grid_position(use_cell):
		return use_cell
	return _get_stool_use_cell_with_distance_map(stool, _get_grid_distance_map(start_cell, true), true)


func _get_stool_use_cell_with_distance_map(stool: Node2D, distance_map: Dictionary, allow_occupied: bool = false) -> Vector2i:
	if stool == null or _room_map == null:
		return INVALID_GRID_POSITION
	var stool_cell := _get_furniture_grid_position(stool)
	if not _is_valid_grid_position(stool_cell):
		return INVALID_GRID_POSITION

	var stool_footprint := _get_furniture_footprint(stool)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := AICharacterGridMovementHelper.get_side_candidate_cells(stool_cell, stool_footprint, actor_footprint)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF

	for candidate in candidates:
		if not _is_target_cell_walkable(candidate, actor_footprint, allow_occupied):
			continue
		var path_score := _get_grid_distance_score(distance_map, candidate)
		if path_score < 0.0:
			continue
		var candidate_position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance_score := _body.global_position.distance_squared_to(candidate_position) / 1000000.0
		var score := path_score + distance_score
		if nearest_cell == INVALID_GRID_POSITION or score < nearest_score:
			nearest_cell = candidate
			nearest_score = score
	return nearest_cell


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
		if to_target.length() > grid_arrival_distance:
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
		if to_waypoint.length() > grid_arrival_distance:
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


func _get_grid_distance_map(start_cell: Vector2i, allow_occupied: bool = false) -> Dictionary:
	var walkable_callable := Callable(self, "_is_target_cell_walkable")
	if allow_occupied:
		walkable_callable = Callable(self, "_is_target_cell_inside")
	return AICharacterGridMovementHelper.get_grid_distance_map(
		start_cell,
		_get_actor_grid_footprint(),
		walkable_callable,
		INVALID_GRID_POSITION
	)


func _get_grid_distance_score(distance_map: Dictionary, target_cell: Vector2i) -> float:
	return AICharacterGridMovementHelper.get_grid_distance_score(distance_map, target_cell, INVALID_GRID_POSITION)


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


func _snap_body_to_current_grid_center() -> bool:
	if _body == null or _room_map == null:
		return false
	var footprint := _get_actor_grid_footprint()
	var snap_cell := _get_current_actor_top_left_grid_position()
	if not _is_target_cell_walkable(snap_cell, footprint):
		snap_cell = _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if not _is_valid_grid_position(snap_cell):
		return false
	var snap_position := _room_map.grid_to_world_area_center(snap_cell, footprint)
	var changed := _body.global_position.distance_squared_to(snap_position) > 0.001
	_body.global_position = snap_position
	_path_cells.clear()
	return changed


func _is_target_cell_walkable(cell: Vector2i, footprint: Vector2i, allow_occupied: bool = false) -> bool:
	if not _is_target_cell_inside(cell, footprint):
		return false
	if allow_occupied:
		return true
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


func _is_target_cell_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	return _room_map.is_grid_area_inside(cell, footprint)


func _get_target_position() -> Vector2:
	if _target_cell != INVALID_GRID_POSITION and _room_map != null:
		return _room_map.grid_to_world_area_center(_target_cell, _get_actor_grid_footprint())
	if _target_stool != null:
		return _target_stool.global_position
	return _body.global_position


func _get_stool_use_position(use_cell: Vector2i) -> Vector2:
	if _room_map == null or not _is_valid_grid_position(use_cell):
		return _body.global_position if _body != null else Vector2.ZERO
	return _room_map.grid_to_world_area_center(use_cell, _get_actor_grid_footprint())


func _get_stool_sit_position(stool: Node2D) -> Vector2:
	if stool == null:
		return _body.global_position if _body != null else Vector2.ZERO
	if _room_map != null:
		var stool_cell := _get_furniture_grid_position(stool)
		if _is_valid_grid_position(stool_cell):
			var stool_footprint := _get_furniture_footprint(stool)
			var actor_footprint := _get_actor_grid_footprint()
			var actor_top_left := Vector2i(
				stool_cell.x + floori(float(stool_footprint.x - actor_footprint.x) * 0.5),
				stool_cell.y + stool_footprint.y - actor_footprint.y
			)
			return _room_map.grid_to_world_area_center(actor_top_left, actor_footprint)
	if stool.has_method("get_sit_target_global_position"):
		var target_position: Vector2 = stool.call("get_sit_target_global_position")
		return target_position
	return stool.global_position


func _face_stool() -> void:
	if _target_stool == null or _body == null or not is_instance_valid(_target_stool):
		_facing_direction = Vector2.DOWN
		return
	var to_stool := _target_stool.global_position - _body.global_position
	if to_stool.length_squared() > 0.001:
		_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_stool)
	else:
		_facing_direction = Vector2.DOWN


func _set_reading_stool(stool: Node2D) -> void:
	if _reading_stool == stool:
		return
	_clear_reading_stool_lock()
	_reading_stool = stool
	if _reading_stool == null:
		return
	_reading_stool.set_meta(BUILD_LOCK_META, true)
	_reading_stool.set_meta(BUILD_LOCK_REASON_META, "Reading")


func _clear_reading_stool_lock() -> void:
	if _reading_stool == null:
		return
	if is_instance_valid(_reading_stool):
		if _reading_stool.has_meta(BUILD_LOCK_META):
			_reading_stool.remove_meta(BUILD_LOCK_META)
		if _reading_stool.has_meta(BUILD_LOCK_REASON_META):
			_reading_stool.remove_meta(BUILD_LOCK_REASON_META)
	_reading_stool = null


func _get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null or not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


func _get_furniture_footprint(furniture: Node2D) -> Vector2i:
	if furniture == null:
		return Vector2i(1, 1)
	if furniture.has_method("get_grid_footprint"):
		var method_footprint: Vector2i = furniture.call("get_grid_footprint")
		return Vector2i(maxi(method_footprint.x, 1), maxi(method_footprint.y, 1))
	if furniture.has_meta("grid_footprint"):
		var meta_footprint: Vector2i = furniture.get_meta("grid_footprint", Vector2i(1, 1))
		return Vector2i(maxi(meta_footprint.x, 1), maxi(meta_footprint.y, 1))
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


func _get_seconds_per_page() -> float:
	var real_seconds_per_game_minute := 1.0
	if _clock != null:
		real_seconds_per_game_minute = maxf(_clock.real_seconds_per_game_minute, 0.01)
	return maxf(reading_game_minutes_per_page, 0.1) * real_seconds_per_game_minute


func _get_book_progress_ratio() -> float:
	var page_count := _get_page_count()
	if page_count <= 0:
		return 0.0
	return clampf(float(_get_read_pages()) / float(page_count), 0.0, 1.0)


func _get_read_pages() -> int:
	if _book == null:
		return 0
	var library := _get_book_library()
	if library == null or not library.has_method("get_read_pages"):
		return 0
	return maxi(int(library.call("get_read_pages", _book.get_item_id())), 0)


func _get_page_count() -> int:
	if _book == null:
		return 1
	return maxi(_book.page_count, 1)


func _get_book_library() -> Node:
	return get_node_or_null("/root/BookLibrary")


func _is_body_sleeping() -> bool:
	if _body == null or not _body.has_method("is_sleeping"):
		return false
	return _body.call("is_sleeping") == true


func _is_body_working() -> bool:
	if _body == null or not _body.has_method("is_working"):
		return false
	return _body.call("is_working") == true


func _get_book_display_name(book: BookData) -> String:
	if book == null:
		return ""
	if not book.display_name.is_empty():
		return book.display_name
	return String(book.get_item_id())


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log")
	if message_log != null and message_log.has_method("add_message"):
		message_log.call("add_message", message)


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as CharacterBody2D
	if _need_planner == null and not need_planner_path.is_empty():
		_need_planner = get_node_or_null(need_planner_path) as NeedDrivenAIPlanner
	if _skills_module == null and not skills_module_path.is_empty():
		_skills_module = get_node_or_null(skills_module_path) as AICharacterSkillsModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("game_clock") as GameClockSystem
