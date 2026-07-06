extends Node
class_name HudButtonFrameController

const RightHudLayout := preload("res://Scripts/UI/HUD/Modules/RightHudLayoutModule.gd")

const NORMAL_BG := Color(0.10, 0.10, 0.12, 0.95)
const HOVER_BG := Color(0.15, 0.15, 0.18, 0.98)
const PRESSED_BG := Color(0.04, 0.20, 0.22, 1.0)
const DISABLED_BG := Color(0.08, 0.08, 0.09, 0.62)
const NORMAL_BORDER := Color(0.26, 0.28, 0.32, 1.0)
const HOVER_BORDER := Color(0.00, 1.65, 1.65, 0.95)
const PRESSED_BORDER := Color(0.25, 2.4, 2.4, 1.0)
const DISABLED_BORDER := Color(0.18, 0.18, 0.20, 0.8)
const ACTIVE_BORDER := Color(1.0, 0.0, 0.95, 1.0)
const NORMAL_BORDER_WIDTH := 1
const HOVER_BORDER_WIDTH := 2
const PRESSED_BORDER_WIDTH := 2
const DISABLED_BORDER_WIDTH := 1
const ACTIVE_BORDER_WIDTH := 4
const MOVEMENT_LOCK_CONTROLLER_GROUP: StringName = &"hud_movement_lock_controller"

const BUTTON_TO_UI := {
	"RobinHudButton": "AICharacterHud",
	"ShopButton": "ShopMenu",
	"BookButton": "BookLibraryUI",
	"InventoryButton": "InventoryUI",
	"MoveButton": "MoveMenu",
	"WorkCreditButton": "WorkMenu",
	"CraftButton": "CraftMenu",
	"SettingsButton": "GameOptionsOverlay",
	"EncyclopediaButton": "EncyclopediaOverlay",
	"BillButton": "BillPanel",
}

const TOGGLE_STATE_BUTTONS := [
	"BuildModeButton",
]

const MOVEMENT_LOCK_BUTTONS := [
	"MoveButton",
	"WorkCreditButton",
]

const MOVEMENT_LOCK_ACTION_IDS := [
	&"map_travel",
	&"part_time_work",
]

var _movement_buttons_locked: bool = false
var _movement_button_original_disabled: Dictionary = {}


func _ready() -> void:
	if not is_in_group(MOVEMENT_LOCK_CONTROLLER_GROUP):
		add_to_group(MOVEMENT_LOCK_CONTROLLER_GROUP)
	call_deferred("_connect_and_sync")


func _process(_delta: float) -> void:
	_sync_movement_button_locks()


func refresh_movement_button_locks() -> void:
	_sync_movement_button_locks(true)


func _connect_and_sync() -> void:
	RightHudLayout.apply_button_layout(get_parent())
	_connect_open_ui_signals()
	_connect_toggle_state_button_signals()
	_sync_movement_button_locks(true)
	_sync_all_button_frames()


func _connect_open_ui_signals() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_TO_UI.keys():
		var ui_node := parent_node.get_node_or_null(String(BUTTON_TO_UI[button_name]))
		if not (ui_node is CanvasItem):
			continue
		var canvas_item := ui_node as CanvasItem
		var callable := Callable(self, "_on_ui_visibility_changed").bind(String(button_name), canvas_item)
		if not canvas_item.visibility_changed.is_connected(callable):
			canvas_item.visibility_changed.connect(callable)


func _connect_toggle_state_button_signals() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in TOGGLE_STATE_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		if button == null:
			continue
		var callable := Callable(self, "_on_toggle_button_changed").bind(button)
		if not button.toggled.is_connected(callable):
			button.toggled.connect(callable)
		var pressed_callable := Callable(self, "_on_toggle_button_pressed").bind(button)
		if not button.pressed.is_connected(pressed_callable):
			button.pressed.connect(pressed_callable)


func _sync_all_button_frames() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in BUTTON_TO_UI.keys():
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		var ui_node := parent_node.get_node_or_null(String(BUTTON_TO_UI[button_name]))
		_apply_button_frame(button, _is_canvas_item_visible(ui_node))
	for button_name in TOGGLE_STATE_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		_apply_button_frame(button, button != null and button.button_pressed)
	for button_name in RightHudLayout.PASSIVE_FRAME_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		_apply_button_frame(button, false)


func _sync_movement_button_locks(force: bool = false) -> void:
	var should_lock := _should_lock_movement_buttons()
	if not force and should_lock == _movement_buttons_locked:
		return
	_movement_buttons_locked = should_lock
	_apply_movement_button_lock(should_lock)
	_sync_all_button_frames()


func _should_lock_movement_buttons() -> bool:
	if _is_move_menu_processing():
		return true
	if _is_work_menu_processing():
		return true
	var robin := _get_robin_actor()
	if robin == null or not robin.has_method("get_current_need_action_id"):
		return false
	var action_id_value: Variant = robin.call("get_current_need_action_id")
	var action_id: StringName = &""
	if action_id_value is StringName:
		action_id = action_id_value
	else:
		action_id = StringName(String(action_id_value))
	return MOVEMENT_LOCK_ACTION_IDS.has(action_id)


func _is_move_menu_processing() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return false
	var move_menu := parent_node.get_node_or_null("MoveMenu")
	if move_menu == null:
		return false
	return move_menu.get("_is_map_move_processing") == true


func _is_work_menu_processing() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return false
	var work_menu := parent_node.get_node_or_null("WorkMenu")
	if work_menu == null:
		return false
	if work_menu.has_method("is_work_processing"):
		return work_menu.call("is_work_processing") == true
	return work_menu.get("_is_work_processing") == true


func _get_robin_actor() -> Node:
	var parent_node := get_parent()
	if parent_node != null:
		var scene_root := parent_node.get_parent()
		if scene_root != null:
			var robin := scene_root.get_node_or_null("Robin")
			if robin != null:
				return robin
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Robin")


func _apply_movement_button_lock(locked: bool) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for button_name in MOVEMENT_LOCK_BUTTONS:
		var button := parent_node.get_node_or_null(String(button_name)) as Button
		if button == null:
			continue
		if locked:
			if not _movement_button_original_disabled.has(button_name):
				_movement_button_original_disabled[button_name] = button.disabled
			button.disabled = true
		else:
			button.disabled = bool(_movement_button_original_disabled.get(button_name, false))
			_movement_button_original_disabled.erase(button_name)


func _on_ui_visibility_changed(button_name: String, canvas_item: CanvasItem) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var button := parent_node.get_node_or_null(button_name) as Button
	_apply_button_frame(button, canvas_item.visible)


func _on_toggle_button_changed(_enabled: bool, button: Button) -> void:
	_apply_button_frame(button, button != null and button.button_pressed)


func _on_toggle_button_pressed(button: Button) -> void:
	call_deferred("_sync_toggle_button_frame", button)


func _sync_toggle_button_frame(button: Button) -> void:
	_apply_button_frame(button, button != null and button.button_pressed)


func _is_canvas_item_visible(node: Node) -> bool:
	if node == null:
		return false
	if node is CanvasItem:
		return (node as CanvasItem).visible
	return false


func _apply_button_frame(button: Button, is_active: bool) -> void:
	if button == null:
		return
	if is_active:
		button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("focus", _make_style(HOVER_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		button.add_theme_stylebox_override("disabled", _make_style(DISABLED_BG, ACTIVE_BORDER, ACTIVE_BORDER_WIDTH))
		return
	button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, NORMAL_BORDER, NORMAL_BORDER_WIDTH))
	button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, HOVER_BORDER, HOVER_BORDER_WIDTH))
	button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, PRESSED_BORDER, PRESSED_BORDER_WIDTH))
	button.add_theme_stylebox_override("focus", _make_style(HOVER_BG, HOVER_BORDER, HOVER_BORDER_WIDTH))
	button.add_theme_stylebox_override("disabled", _make_style(DISABLED_BG, DISABLED_BORDER, DISABLED_BORDER_WIDTH))


func _make_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3.0)
	return style
