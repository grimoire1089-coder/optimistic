extends AICharacterHydrateBehaviorModule
class_name AICharacterTableSeatHydrateModule

const CHAIR_CLAIMED_BY_META := &"ai_seat_reserved_by"
const CHAIR_CLAIMED_NAME_META := &"ai_seat_reserved_name"
const CHAIR_CLAIMED_REASON_META := &"ai_seat_reserved_reason"


func _exit_tree() -> void:
	_clear_chair_claim(_target_dining_seat)


func _has_valid_dining_seat_target() -> bool:
	if not super._has_valid_dining_seat_target():
		return false
	return _can_use_chair(_target_dining_seat)


func _set_dining_seat_target(info: Dictionary) -> void:
	var previous_chair := _target_dining_seat
	super._set_dining_seat_target(info)
	if previous_chair != _target_dining_seat:
		_clear_chair_claim(previous_chair)
	_claim_current_chair()


func _clear_dining_seat_target() -> void:
	_clear_chair_claim(_target_dining_seat)
	super._clear_dining_seat_target()


func _lock_dining_seat_if_needed() -> void:
	super._lock_dining_seat_if_needed()
	_clear_chair_claim(_target_dining_seat)


func _can_use_chair(chair: Node2D) -> bool:
	if chair == null:
		return false
	if chair.has_meta(BUILD_LOCK_META) and chair != _target_dining_seat:
		return false
	if not chair.has_meta(CHAIR_CLAIMED_BY_META):
		return true
	var claimed_by := int(chair.get_meta(CHAIR_CLAIMED_BY_META, 0))
	return claimed_by == get_instance_id()


func _claim_current_chair() -> void:
	if _target_dining_seat == null or not is_instance_valid(_target_dining_seat):
		return
	_target_dining_seat.set_meta(CHAIR_CLAIMED_BY_META, get_instance_id())
	_target_dining_seat.set_meta(CHAIR_CLAIMED_NAME_META, _body.name if _body != null else name)
	_target_dining_seat.set_meta(CHAIR_CLAIMED_REASON_META, "DiningTarget")


func _clear_chair_claim(chair: Node2D) -> void:
	if chair == null or not is_instance_valid(chair):
		return
	if not chair.has_meta(CHAIR_CLAIMED_BY_META):
		return
	var claimed_by := int(chair.get_meta(CHAIR_CLAIMED_BY_META, 0))
	if claimed_by != get_instance_id():
		return
	chair.remove_meta(CHAIR_CLAIMED_BY_META)
	if chair.has_meta(CHAIR_CLAIMED_NAME_META):
		chair.remove_meta(CHAIR_CLAIMED_NAME_META)
	if chair.has_meta(CHAIR_CLAIMED_REASON_META):
		chair.remove_meta(CHAIR_CLAIMED_REASON_META)
