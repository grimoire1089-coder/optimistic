extends PanelContainer
class_name AICharacterHud

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var action_label: Label = $MarginContainer/Rows/ActionLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var needs_panel: CharacterNeedsPanel = $MarginContainer/Rows/CharacterNeedsPanel

var _actor: RobinWanderActor
var _refresh_timer: float = 0.0

func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_hud)

func show_actor(actor: RobinWanderActor) -> void:
	_actor = actor
	visible = true
	if _actor == null:
		title_label.text = "AI Character"
		needs_panel.set_character_needs(null)
		_update_action_label()
		return
	title_label.text = _actor.display_name
	needs_panel.set_needs_module(_actor.get_needs_module())
	_update_action_label()

func hide_hud() -> void:
	visible = false

func clear_actor() -> void:
	_actor = null
	needs_panel.set_character_needs(null)
	_update_action_label()
	hide_hud()

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
