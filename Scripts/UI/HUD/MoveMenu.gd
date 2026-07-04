extends PanelContainer
class_name MoveMenu

const MENU_SIZE := Vector2(760.0, 760.0)
const MENU_OFFSET_LEFT := 580.0
const MENU_OFFSET_TOP := 80.0
const MENU_OFFSET_RIGHT := 1340.0
const MENU_OFFSET_BOTTOM := 840.0

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var action_list: VBoxContainer = $MarginContainer/Rows/ActionList
@onready var move_action_button: Button = $MarginContainer/Rows/ActionList/MoveActionButton
@onready var explore_action_button: Button = $MarginContainer/Rows/ActionList/ExploreActionButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel


func _ready() -> void:
	visible = false
	_apply_shop_aligned_layout()
	if not is_in_group(&"move_menu"):
		add_to_group(&"move_menu")
	close_button.pressed.connect(close_menu)
	move_action_button.pressed.connect(_on_move_action_pressed)
	explore_action_button.pressed.connect(_on_explore_action_pressed)


func open_menu() -> void:
	visible = true
	_apply_shop_aligned_layout()
	detail_label.text = "移動または探索を選んでください。"


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _on_move_action_pressed() -> void:
	detail_label.text = "移動はまだ準備中です。"


func _on_explore_action_pressed() -> void:
	detail_label.text = "探索はまだ準備中です。"


func _apply_shop_aligned_layout() -> void:
	custom_minimum_size = MENU_SIZE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = MENU_OFFSET_LEFT
	offset_top = MENU_OFFSET_TOP
	offset_right = MENU_OFFSET_RIGHT
	offset_bottom = MENU_OFFSET_BOTTOM
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
