extends AICharacterSleepBehaviorModule
class_name AICharacterReservedSleepBehaviorModule

const BEDDING_RESERVED_BY_META := &"ai_sleep_reserved_by"
const BEDDING_RESERVED_NAME_META := &"ai_sleep_reserved_name"
const BEDDING_RESERVED_REASON_META := &"ai_sleep_reserved_reason"
const BEDDING_BUILD_LOCK_OWNER_META := &"ai_sleep_build_lock_owner"
const SHARED_BUILD_LOCK_META := &"build_locked_by_sleep"
const SHARED_BUILD_LOCK_REASON_META := &"build_lock_reason"


func _exit_tree() -> void:
	_stop_sleeping()


func _is_bedding(furniture: Node2D) -> bool:
	if not super._is_bedding(furniture):
		return false
	return _can_use_bedding(furniture)


func _set_bedding_target(bedding: Node2D) -> void:
	var previous_bedding := _target_bedding
	if bedding == null:
		_clear_bedding_target()
		return
	if not _can_use_bedding(bedding):
		_clear_bedding_target()
		return
	if previous_bedding != bedding:
		_clear_bedding_reservation(previous_bedding)
	super._set_bedding_target(bedding)
	if not _claim_bedding(bedding):
		super._clear_bedding_target()


func _clear_bedding_target() -> void:
	var bedding := _target_bedding
	_clear_bedding_reservation(bedding)
	super._clear_bedding_target()


func _set_sleeping_bedding(bedding: Node2D) -> void:
	super._set_sleeping_bedding(bedding)
	if bedding == null or not is_instance_valid(bedding):
		return
	bedding.set_meta(BEDDING_BUILD_LOCK_OWNER_META, get_instance_id())


func _clear_sleeping_bedding_lock() -> void:
	if _sleeping_bedding == null:
		return
	var bedding := _sleeping_bedding
	if is_instance_valid(bedding):
		var owner_id := int(bedding.get_meta(BEDDING_BUILD_LOCK_OWNER_META, 0))
		if owner_id == get_instance_id():
			if bedding.has_meta(SHARED_BUILD_LOCK_META):
				bedding.remove_meta(SHARED_BUILD_LOCK_META)
			if bedding.has_meta(SHARED_BUILD_LOCK_REASON_META):
				bedding.remove_meta(SHARED_BUILD_LOCK_REASON_META)
			if bedding.has_meta(BEDDING_BUILD_LOCK_OWNER_META):
				bedding.remove_meta(BEDDING_BUILD_LOCK_OWNER_META)
	_sleeping_bedding = null


func _can_use_bedding(bedding: Node2D) -> bool:
	if bedding == null or not is_instance_valid(bedding):
		return false
	if bedding.has_meta(BEDDING_RESERVED_BY_META):
		return int(bedding.get_meta(BEDDING_RESERVED_BY_META, 0)) == get_instance_id()
	if bedding.has_meta(SHARED_BUILD_LOCK_META) and bool(bedding.get_meta(SHARED_BUILD_LOCK_META, false)):
		return int(bedding.get_meta(BEDDING_BUILD_LOCK_OWNER_META, 0)) == get_instance_id()
	return true


func _claim_bedding(bedding: Node2D) -> bool:
	if not _can_use_bedding(bedding):
		return false
	bedding.set_meta(BEDDING_RESERVED_BY_META, get_instance_id())
	bedding.set_meta(BEDDING_RESERVED_NAME_META, _body.name if _body != null else name)
	bedding.set_meta(BEDDING_RESERVED_REASON_META, "SleepTarget")
	return true


func _clear_bedding_reservation(bedding: Node2D) -> void:
	if bedding == null or not is_instance_valid(bedding):
		return
	if int(bedding.get_meta(BEDDING_RESERVED_BY_META, 0)) != get_instance_id():
		return
	if bedding.has_meta(BEDDING_RESERVED_BY_META):
		bedding.remove_meta(BEDDING_RESERVED_BY_META)
	if bedding.has_meta(BEDDING_RESERVED_NAME_META):
		bedding.remove_meta(BEDDING_RESERVED_NAME_META)
	if bedding.has_meta(BEDDING_RESERVED_REASON_META):
		bedding.remove_meta(BEDDING_RESERVED_REASON_META)
