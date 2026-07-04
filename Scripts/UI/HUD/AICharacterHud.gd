extends PanelContainer
class_name AICharacterHud

const FRONT_Z_INDEX := 200

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var action_label: Label = $MarginContainer/Rows/ActionLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var tab_container: TabContainer = $MarginContainer/Rows/Tabs
@onready var needs_panel: CharacterNeedsPanel = $MarginContainer/Rows/Tabs/NeedsTab/CharacterNeedsPanel
@onready var mood_panel: CharacterMoodPanel = $MarginContainer/Rows/Tabs/MoodTab/CharacterMoodPanel
@onready var action_queue_panel: AICharacterActionQueuePanel = $MarginContainer/Rows/Tabs/ActionQueueTab/ActionQueueScroll/ActionQueueRows
@onready var skills_panel: CharacterSkillsPanel = $MarginContainer/Rows/Tabs/SkillsTab/CharacterSkillsPanel

var _actor: RobinWanderActor
var _refresh_timer: float = 0.0
var _last_logged_need_id: StringName = &""
var _last_logged_action_id: StringName = &""

func _ready() -> void:
	visible = false
	_apply_front_layer_priority()
	close_button.pressed.connect(hide_hud)
	_setup_tabs()
	_push_debug_result("AI HUD", "ready", true, "非表示状態で待機します")

func toggle_actor(actor: RobinWanderActor) -> void:
	if visible:
		hide_hud()
		return
	show_actor(actor)

func show_actor(actor: RobinWanderActor) -> void:
	_push_debug_message("AI HUD", "show_actor 開始")
	_actor = actor
	visible = true
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
	title_label.text = _actor.display_name
	needs_panel.set_needs_module(_actor.get_needs_module())
	mood_panel.set_mood_module(_actor.get_mood_module())
	action_queue_panel.set_actor(_actor)
	if skills_panel != null:
		skills_panel.set_skills_module(_actor.get_skills_module())
	_update_action_label()
	_push_debug_result("AI HUD", "show_actor", true, "target=%s" % _actor.display_name)

func hide_hud() -> void:
	visible = false
	_push_debug_result("AI HUD", "hide_hud", true, "HUD を閉じました")

func clear_actor() -> void:
	var previous_actor_name := "none"
	if _actor != null:
		previous_actor_name = _actor.display_name
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
	var need_id := _actor.get_current_lowest_need_id()
	var action_id := _actor.get_current_need_action_id()
	var action_text := _actor.get_current_action_display_text()
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
		"AI:%s" % _actor.display_name,
		"現在の判断: lowest_need=%s / next_action=%s" % [String(need_id), String(action_id)]
	)

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
