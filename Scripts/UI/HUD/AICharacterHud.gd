extends PanelContainer
class_name AICharacterHud

const FRONT_Z_INDEX := 200
const HUD_WIDTH := 480.0
const HUD_HEIGHT := 456.0
const HUD_RIGHT_MARGIN := 24.0
const HUD_BOTTOM_MARGIN := 92.0
const NEED_BAR_WIDTH := 290.0
const READ_ACTION_ID: StringName = &"read_book"
const CRAFT_ACTION_ID: StringName = &"crafting"

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var action_label: Label = $MarginContainer/Rows/ActionLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var tab_container: TabContainer = $MarginContainer/Rows/Tabs
@onready var needs_panel: CharacterNeedsPanel = $MarginContainer/Rows/Tabs/NeedsTab/CharacterNeedsPanel
@onready var mood_panel: CharacterMoodPanel = $MarginContainer/Rows/Tabs/MoodTab/CharacterMoodPanel
@onready var action_queue_panel: AICharacterActionQueuePanel = $MarginContainer/Rows/Tabs/ActionQueueTab/ActionQueueScroll/ActionQueueRows
@onready var skills_panel: CharacterSkillsPanel = $MarginContainer/Rows/Tabs/SkillsTab/CharacterSkillsPanel

var _actor: Node
var _refresh_timer: float = 0.0
var _last_logged_need_id: StringName = &""
var _last_logged_action_id: StringName = &""


func _ready() -> void:
	visible = false
	_apply_wide_layout()
	_apply_front_layer_priority()
	close_button.pressed.connect(hide_hud)
	_setup_tabs()
	_push_debug_result("AI HUD", "ready", true, "非表示状態で待機します")


func toggle_actor(actor: Node) -> void:
	if visible and _actor == actor:
		hide_hud()
		return
	show_actor(actor)


func show_actor(actor: Node) -> void:
	_push_debug_message("AI HUD", "show_actor 開始")
	_actor = actor
	visible = true
	_apply_wide_layout()
	_apply_front_layer_priority()
	_last_logged_need_id = &""
	_last_logged_action_id = &""
	if tab_container != null:
		tab_container.current_tab = 0
	if _actor == null:
		title_label.text = "AI Character"
		needs_panel.set_character_needs(null)
		mood_panel.set_mood_module(null)
		action_queue_panel.clear_actor()
		if skills_panel != null:
			skills_panel.set_skills_module(null)
		_update_action_label()
		_push_debug_result("AI HUD", "show_actor", false, "actor が null です")
		return
	var actor_name := _get_actor_display_name(_actor)
	title_label.text = actor_name
	needs_panel.set_needs_module(_get_actor_needs_module())
	mood_panel.set_mood_module(_get_actor_mood_module())
	action_queue_panel.set_actor(_actor)
	if skills_panel != null:
		skills_panel.set_skills_module(_get_actor_skills_module())
	_update_action_label()
	_push_debug_result("AI HUD", "show_actor", true, "target=%s" % actor_name)


func hide_hud() -> void:
	visible = false
	_push_debug_result("AI HUD", "hide_hud", true, "HUD を閉じました")


func clear_actor() -> void:
	var previous_actor_name := "none"
	if _actor != null:
		previous_actor_name = _get_actor_display_name(_actor)
	_actor = null
	_last_logged_need_id = &""
	_last_logged_action_id = &""
	needs_panel.set_character_needs(null)
	mood_panel.set_mood_module(null)
	action_queue_panel.clear_actor()
	if skills_panel != null:
		skills_panel.set_skills_module(null)
	_update_action_label()
	hide_hud()
	_push_debug_result("AI HUD", "clear_actor", true, "previous=%s" % previous_actor_name)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.25
	_update_action_label()


func _apply_wide_layout() -> void:
	custom_minimum_size = Vector2(HUD_WIDTH, HUD_HEIGHT)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, false)
	offset_left = -HUD_RIGHT_MARGIN - HUD_WIDTH
	offset_top = -HUD_BOTTOM_MARGIN - HUD_HEIGHT
	offset_right = -HUD_RIGHT_MARGIN
	offset_bottom = -HUD_BOTTOM_MARGIN
	if needs_panel != null:
		needs_panel.bar_width = NEED_BAR_WIDTH
		needs_panel.refresh()


func _apply_front_layer_priority() -> void:
	z_as_relative = false
	z_index = FRONT_Z_INDEX
	call_deferred("_move_to_front_safely")


func _move_to_front_safely() -> void:
	if is_inside_tree():
		move_to_front()


func _setup_tabs() -> void:
	if tab_container == null:
		return
	if tab_container.get_tab_count() >= 1:
		tab_container.set_tab_title(0, "欲求")
	if tab_container.get_tab_count() >= 2:
		tab_container.set_tab_title(1, "気分")
	if tab_container.get_tab_count() >= 3:
		tab_container.set_tab_title(2, "行動")
	if tab_container.get_tab_count() >= 4:
		tab_container.set_tab_title(3, "スキル")
	tab_container.current_tab = 0


func _update_action_label() -> void:
	if _actor == null:
		action_label.text = "行動: -"
		return
	var need_id := _get_actor_lowest_need_id()
	var action_id := _get_actor_need_action_id()
	var action_text := _get_actor_action_text()
	action_label.text = "行動: %s" % action_text
	_log_ai_action_if_changed(need_id, action_id)


func _log_ai_action_if_changed(need_id: StringName, action_id: StringName) -> void:
	if _actor == null:
		return
	if need_id == _last_logged_need_id and action_id == _last_logged_action_id:
		return
	_last_logged_need_id = need_id
	_last_logged_action_id = action_id
	_push_debug_message(
		"AI:%s" % _get_actor_display_name(_actor),
		"現在の判断: lowest_need=%s / next_action=%s" % [String(need_id), String(action_id)]
	)


func _get_actor_display_name(actor: Node) -> String:
	if actor == null:
		return "AI Character"
	var display_name_value: Variant = actor.get("display_name")
	if display_name_value != null and not str(display_name_value).is_empty():
		return str(display_name_value)
	return actor.name


func _get_actor_needs_module() -> CharacterNeedsModule:
	if _actor == null or not _actor.has_method("get_needs_module"):
		return null
	return _actor.call("get_needs_module") as CharacterNeedsModule


func _get_actor_mood_module() -> CharacterMoodModule:
	if _actor == null or not _actor.has_method("get_mood_module"):
		return null
	return _actor.call("get_mood_module") as CharacterMoodModule


func _get_actor_skills_module() -> AICharacterSkillsModule:
	if _actor == null:
		return null
	if _actor.has_method("get_skills_module"):
		var method_module := _actor.call("get_skills_module") as AICharacterSkillsModule
		if method_module != null:
			return method_module
	return _actor.get_node_or_null("AICharacterSkillsModule") as AICharacterSkillsModule


func _get_actor_lowest_need_id() -> StringName:
	if _actor == null or not _actor.has_method("get_current_lowest_need_id"):
		return &""
	return StringName(String(_actor.call("get_current_lowest_need_id")))


func _get_actor_need_action_id() -> StringName:
	var runner := _get_actor_action_runner()
	if runner != null and _is_explicit_action_id(runner.get_active_action_id()):
		return runner.get_active_action_id()
	if _actor == null or not _actor.has_method("get_current_need_action_id"):
		return CharacterNeedActionIds.IDLE
	return StringName(String(_actor.call("get_current_need_action_id")))


func _get_actor_action_text() -> String:
	var runner := _get_actor_action_runner()
	if runner != null and _is_explicit_action_id(runner.get_active_action_id()):
		return runner.get_current_action_display_text()
	if _actor == null or not _actor.has_method("get_current_action_display_text"):
		return "-"
	return str(_actor.call("get_current_action_display_text"))


func _is_explicit_action_id(action_id: StringName) -> bool:
	return action_id == READ_ACTION_ID or action_id == CRAFT_ACTION_ID


func _get_actor_action_runner() -> AICharacterActionRunner:
	if _actor == null or not _actor.has_method("get_ai_action_runner"):
		return null
	return _actor.call("get_ai_action_runner") as AICharacterActionRunner


func _get_message_log() -> MessageLogPanel:
	var node := get_tree().get_first_node_in_group(&"message_log")
	if node is MessageLogPanel:
		return node
	return null


func _push_debug_message(source: String, message: String) -> void:
	var message_log := _get_message_log()
	if message_log == null:
		return
	message_log.add_debug_message("[%s] %s" % [source, message])


func _push_debug_result(source: String, action: String, success: bool, detail: String = "") -> void:
	var message_log := _get_message_log()
	if message_log == null:
		return
	message_log.add_debug_result(source, action, success, detail)
