extends PanelContainer
class_name CraftMenu

signal crafting_method_selected(method_id: StringName)

const TITLE_TEXT_CODES := [0x5236, 0x4f5c]
const COOKING_BUTTON_TEXT_CODES := [0x6599, 0x7406, 0x0a, 0x5236, 0x4f5c, 0x65b9, 0x5f0f]
const GUIDE_TEXT_CODES := [0x5236, 0x4f5c, 0x65b9, 0x5f0f, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002, 0x0a, 0x73fe, 0x5728, 0x306f, 0x6599, 0x7406, 0x306e, 0x307f, 0x5229, 0x7528, 0x3067, 0x304d, 0x307e, 0x3059, 0x3002]
const COOKING_DETAIL_TEXT_CODES := [0x6599, 0x7406, 0x5236, 0x4f5c, 0x3092, 0x9078, 0x3073, 0x307e, 0x3057, 0x305f, 0x3002, 0x0a, 0x6b21, 0x306e, 0x6bb5, 0x968e, 0x3067, 0x6599, 0x7406, 0x30ec, 0x30b7, 0x30d4, 0x4e00, 0x89a7, 0x306b, 0x3064, 0x306a, 0x3052, 0x307e, 0x3059, 0x3002]
const COOKING_MESSAGE_TEXT_CODES := [0x5236, 0x4f5c, 0x65b9, 0x5f0f, 0x3a, 0x20, 0x6599, 0x7406, 0x3092, 0x9078, 0x629e, 0x3057, 0x307e, 0x3057, 0x305f, 0x3002]

@export var cooking_method_id: StringName = &"cooking"
@export var close_after_select: bool = false

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var cooking_button: Button = $MarginContainer/Rows/CategoryList/CookingButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _selected_method_id: StringName = &""


func _ready() -> void:
	visible = false
	if not is_in_group(&"craft_menu"):
		add_to_group(&"craft_menu")
	close_button.pressed.connect(close_menu)
	cooking_button.pressed.connect(_on_cooking_pressed)
	_refresh()


func open_menu() -> void:
	visible = true
	_refresh()


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func get_selected_method_id() -> StringName:
	return _selected_method_id


func _refresh() -> void:
	title_label.text = _string_from_codes(TITLE_TEXT_CODES)
	cooking_button.text = _string_from_codes(COOKING_BUTTON_TEXT_CODES)
	if _selected_method_id == cooking_method_id:
		detail_label.text = _string_from_codes(COOKING_DETAIL_TEXT_CODES)
		return
	detail_label.text = _string_from_codes(GUIDE_TEXT_CODES)


func _on_cooking_pressed() -> void:
	_selected_method_id = cooking_method_id
	detail_label.text = _string_from_codes(COOKING_DETAIL_TEXT_CODES)
	crafting_method_selected.emit(cooking_method_id)
	_push_message(_string_from_codes(COOKING_MESSAGE_TEXT_CODES))
	if close_after_select:
		close_menu()


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log")
	if message_log == null:
		return
	if not message_log.has_method("add_message"):
		return
	message_log.call("add_message", message)


func _string_from_codes(codes: Array) -> String:
	var value := ""
	for code in codes:
		value += String.chr(int(code))
	return value
