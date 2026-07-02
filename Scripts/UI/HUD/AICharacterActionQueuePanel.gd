extends VBoxContainer
class_name AICharacterActionQueuePanel

@export var refresh_interval: float = 0.25

var _actor: RobinWanderActor
var _refresh_timer := 0.0


func _ready() -> void:
	set_process(true)


func set_actor(actor: RobinWanderActor) -> void:
	_actor = actor
	_refresh_timer = 0.0
	refresh_now()


func clear_actor() -> void:
	_actor = null
	refresh_now()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = refresh_interval
	refresh_now()


func refresh_now() -> void:
	_clear_rows()
	if _actor == null:
		_add_label("AI character not selected.")
		return
	_add_label("Current: %s" % _actor.get_current_action_display_text(), 14)
	var planner := _actor.get_need_planner()
	var needs_module := _actor.get_needs_module()
	if planner == null or needs_module == null:
		_add_label("Planner is not connected.")
		return
	var character_needs := needs_module.get_character_needs()
	if character_needs == null or character_needs.needs.is_empty():
		_add_label("No need data.")
		return
	var rows := _build_rows(character_needs, planner, needs_module)
	if rows.is_empty():
		_add_label("No queued actions.")
		return
	_add_label("Priority / Need / Action / State", 12)
	for row in rows:
		_add_row(row)


func _build_rows(character_needs: CharacterNeeds, planner: NeedDrivenAIPlanner, needs_module: CharacterNeedsModule) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for need in character_needs.needs:
		if need == null or need.definition == null:
			continue
		if not need.enabled:
			continue
		var need_id := need.definition.need_id
		rows.append({
			"priority": needs_module.get_need_priority(need_id),
			"need_name": _get_need_name(need),
			"action_id": planner.get_action_id_for_need(need_id),
			"ratio": need.get_ratio(),
			"state": need.get_state(),
		})
	rows.sort_custom(Callable(self, "_sort_rows"))
	return rows


func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := float(a.get("priority", 0.0))
	var b_priority := float(b.get("priority", 0.0))
	if not is_equal_approx(a_priority, b_priority):
		return a_priority > b_priority
	return String(a.get("need_name", "")) < String(b.get("need_name", ""))


func _add_row(row: Dictionary) -> void:
	var priority := float(row.get("priority", 0.0))
	var ratio := float(row.get("ratio", 0.0)) * 100.0
	var need_name := String(row.get("need_name", ""))
	var action_name := _get_action_name(row.get("action_id", &""))
	var state_name := _get_state_name(row.get("state", &""))
	_add_label("%.2f / %s / %s / %s %.0f%%" % [priority, need_name, action_name, state_name, ratio], 11)


func _add_label(text_value: String, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0, 1.0))
	add_child(label)
	return label


func _clear_rows() -> void:
	for child in get_children():
		child.queue_free()


func _get_need_name(need: NeedInstance) -> String:
	if need == null or need.definition == null:
		return "-"
	if not need.definition.display_name.is_empty():
		return need.definition.display_name
	return String(need.definition.need_id)


func _get_action_name(action_id_variant) -> String:
	var action_id := StringName(action_id_variant)
	match action_id:
		CharacterNeedActionIds.IDLE:
			return "Idle"
		CharacterNeedActionIds.EAT:
			return "Eat"
		CharacterNeedActionIds.HYDRATE:
			return "Hydrate"
		CharacterNeedActionIds.REST:
			return "Rest"
		CharacterNeedActionIds.MAINTAIN:
			return "Maintain"
		CharacterNeedActionIds.PLAY:
			return "Play"
		CharacterNeedActionIds.CHAT:
			return "Chat"
		&"crafting":
			return "Craft"
		&"map_travel":
			return "MapTravel"
		_:
			return String(action_id)


func _get_state_name(state_id_variant) -> String:
	var state_id := StringName(state_id_variant)
	match state_id:
		&"critical":
			return "Critical"
		&"low":
			return "Low"
		&"normal":
			return "Normal"
		_:
			return String(state_id)
