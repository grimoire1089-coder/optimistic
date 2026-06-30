extends PanelContainer
class_name AICharacterHud

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var action_label: Label = $MarginContainer/Rows/ActionLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var needs_panel: CharacterNeedsPanel = $MarginContainer/Rows/CharacterNeedsPanel

var _actor: RobinWanderActor
var _refresh_timer: float = 0.0
var _last_logged_need_id: StringName = &""
var _last_logged_action_id: StringName = &""

func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_hud)
	_push_debug_result("AI HUD", "ready", true, "非表示状態で待機します")

func show_actor(actor: RobinWanderActor) -> void:
	_push_debug_message("AI HUD", "show_actor 開始")
	_actor = actor
	visible = true
	_last_logged_need_id = &""
	_last_logged_action_id = &""
	if _actor == null:
		title_label.text = "AI Character"
		needs_panel.set_character_needs(null)
		_update_action_label()
		_push_debug_result("AI HUD", "show_actor", false, "actor が null です")
		return
	title_label.text = _actor.display_name
	needs_panel.set_needs_module(_actor.get_needs_module())
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

func _update_action_label() -> void:
	if _actor == null:
		action_label.text = "欲求行動: -"
		return
	var need_id := _actor.get_current_lowest_need_id()
	var action_id := _actor.get_current_need_action_id()
	action_label.text = "最低欲求: %s / 行動: %s" % [String(need_id), String(action_id)]
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
