extends AICharacterSitBehaviorModule
class_name AICharacterReservedSitBehaviorModule

const SEAT_RESERVED_BY_META := &"ai_seat_reserved_by"
const SEAT_RESERVED_NAME_META := &"ai_seat_reserved_name"
const SEAT_RESERVED_REASON_META := &"ai_seat_reserved_reason"


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
		if not _is_stool_available_for_actor(furniture):
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


func _has_valid_target_stool() -> bool:
	if not super._has_valid_target_stool():
		return false
	return _is_stool_available_for_actor(_target_stool)


func _set_target_stool(stool: Node2D) -> void:
	if _target_stool != stool:
		_clear_reserved_stool(_target_stool)
	super._set_target_stool(stool)
	_reserve_target_stool()


func _clear_target() -> void:
	_clear_reserved_stool(_target_stool)
	super._clear_target()


func _set_sitting_stool(stool: Node2D) -> void:
	super._set_sitting_stool(stool)
	_clear_reserved_stool(stool)


func _is_stool_available_for_actor(stool: Node2D) -> bool:
	if stool == null:
		return false
	if stool.has_meta(BUILD_LOCK_META) and stool != _sitting_stool:
		return false
	if not stool.has_meta(SEAT_RESERVED_BY_META):
		return true
	var reserved_by := int(stool.get_meta(SEAT_RESERVED_BY_META, 0))
	return reserved_by == get_instance_id()


func _reserve_target_stool() -> void:
	if _target_stool == null or not is_instance_valid(_target_stool):
		return
	_target_stool.set_meta(SEAT_RESERVED_BY_META, get_instance_id())
	_target_stool.set_meta(SEAT_RESERVED_NAME_META, _body.name if _body != null else name)
	_target_stool.set_meta(SEAT_RESERVED_REASON_META, "SittingTarget")


func _clear_reserved_stool(stool: Node2D) -> void:
	if stool == null or not is_instance_valid(stool):
		return
	if not stool.has_meta(SEAT_RESERVED_BY_META):
		return
	var reserved_by := int(stool.get_meta(SEAT_RESERVED_BY_META, 0))
	if reserved_by != get_instance_id():
		return
	stool.remove_meta(SEAT_RESERVED_BY_META)
	if stool.has_meta(SEAT_RESERVED_NAME_META):
		stool.remove_meta(SEAT_RESERVED_NAME_META)
	if stool.has_meta(SEAT_RESERVED_REASON_META):
		stool.remove_meta(SEAT_RESERVED_REASON_META)
