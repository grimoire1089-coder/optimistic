extends AICharacterHydrateBehaviorModule
class_name AICharacterTableSeatHydrateModule

const CHAIR_CLAIMED_BY_META := &"ai_seat_reserved_by"
const CHAIR_CLAIMED_NAME_META := &"ai_seat_reserved_name"
const CHAIR_CLAIMED_REASON_META := &"ai_seat_reserved_reason"


func _exit_tree() -> void:
	_clear_chair_claim(_target_dining_seat)


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
