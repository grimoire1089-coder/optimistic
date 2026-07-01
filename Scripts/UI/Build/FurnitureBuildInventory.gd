extends PanelContainer
class_name FurnitureBuildInventory

const CATEGORY_BEDDING: StringName = &"bedding"
const CATEGORY_KITCHEN: StringName = &"kitchen"
const CATEGORY_HYGIENE: StringName = &"hygiene"
const CATEGORY_ENTERTAINMENT: StringName = &"entertainment"
const CATEGORY_DECOR: StringName = &"decor"
const CATEGORY_FLOOR: StringName = &"floor"

@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var floor_placement_module_path: NodePath = NodePath("../../FloorPlacementModule")
@export var simple_mattress_scene: PackedScene
@export var kitchen_module_scene: PackedScene

@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var place_mode_button: Button = $MarginContainer/Rows/ModeButtons/PlaceModeButton
@onready var move_mode_button: Button = $MarginContainer/Rows/ModeButtons/MoveModeButton
@onready var store_mode_button: Button = $MarginContainer/Rows/ModeButtons/StoreModeButton
@onready var bedding_category_button: Button = $MarginContainer/Rows/CategoryButtons/BeddingCategoryButton
@onready var kitchen_category_button: Button = $MarginContainer/Rows/CategoryButtons/KitchenCategoryButton
@onready var hygiene_category_button: Button = $MarginContainer/Rows/CategoryButtons/HygieneCategoryButton
@onready var entertainment_category_button: Button = $MarginContainer/Rows/CategoryButtons/EntertainmentCategoryButton
@onready var decor_category_button: Button = $MarginContainer/Rows/CategoryButtons/DecorCategoryButton
@onready var floor_category_button: Button = $MarginContainer/Rows/CategoryButtons/FloorCategoryButton
@onready var mattress_button: Button = $MarginContainer/Rows/ItemList/SimpleMattressButton
@onready var kitchen_module_button: Button = $MarginContainer/Rows/ItemList/KitchenModuleButton
@onready var floor_place_button: Button = $MarginContainer/Rows/ItemList/FloorPlaceButton
@onready var floor_store_button: Button = $MarginContainer/Rows/ItemList/FloorStoreButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _build_mode_controller: BuildModeController
var _floor_placement: Node
var _current_category_id: StringName = CATEGORY_BEDDING


func _ready() -> void:
	visible = false
	set_process_unhandled_input(true)
	_resolve_controller()
	_resolve_floor_placement()
	_connect_buttons()
	_connect_controller_signals()
	_sync_visibility()
	_sync_mode_buttons()
	_sync_category_buttons()
	_sync_item_category_visibility()
	_sync_floor_buttons()
	_update_category_detail_text()


func _process(_delta: float) -> void:
	_resolve_controller()
	_resolve_floor_placement()
	_sync_visibility()
	_sync_mode_buttons()
	_sync_floor_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			close_build_mode()
			get_viewport().set_input_as_handled()


func close_build_mode() -> void:
	_resolve_controller()
	if _build_mode_controller == null:
		visible = false
		return
	_build_mode_controller.set_build_mode_enabled(false)


func _connect_buttons() -> void:
	if close_button != null:
		close_button.pressed.connect(close_build_mode)
	if place_mode_button != null:
		place_mode_button.pressed.connect(_on_place_mode_pressed)
	if move_mode_button != null:
		move_mode_button.pressed.connect(_on_move_mode_pressed)
	if store_mode_button != null:
		store_mode_button.pressed.connect(_on_store_mode_pressed)
	_connect_category_button(bedding_category_button, CATEGORY_BEDDING)
	_connect_category_button(kitchen_category_button, CATEGORY_KITCHEN)
	_connect_category_button(hygiene_category_button, CATEGORY_HYGIENE)
	_connect_category_button(entertainment_category_button, CATEGORY_ENTERTAINMENT)
	_connect_category_button(decor_category_button, CATEGORY_DECOR)
	_connect_category_button(floor_category_button, CATEGORY_FLOOR)
	if mattress_button != null:
		mattress_button.pressed.connect(_on_simple_mattress_pressed)
	if kitchen_module_button != null:
		kitchen_module_button.pressed.connect(_on_kitchen_module_pressed)
	if floor_place_button != null:
		floor_place_button.pressed.connect(_on_floor_place_pressed)
	if floor_store_button != null:
		floor_store_button.pressed.connect(_on_floor_store_pressed)


func _connect_category_button(button: Button, category_id: StringName) -> void:
	if button == null:
		return
	button.toggle_mode = true
	button.pressed.connect(Callable(self, "_on_category_button_pressed").bind(category_id))


func _on_category_button_pressed(category_id: StringName) -> void:
	_set_category(category_id)


func _set_category(category_id: StringName) -> void:
	_current_category_id = _normalize_category_id(category_id)
	_sync_category_buttons()
	_sync_item_category_visibility()
	_update_category_detail_text()


func _on_place_mode_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_PLACE)
	_update_category_detail_text()


func _on_move_mode_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_MOVE)
	_update_detail_text("移動モード: 置いてある家具をクリック")


func _on_store_mode_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_STORE)
	_update_detail_text("しまうモード: 片付ける家具をクリック")


func _on_simple_mattress_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null or simple_mattress_scene == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_PLACE)
	_build_mode_controller.select_furniture_scene(simple_mattress_scene, &"simple_mattress", Vector2i(2, 4), true, 0)
	_update_detail_text("選択中: シンプルマットレス / 2 x 4 / Rで回転")


func _on_kitchen_module_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null or kitchen_module_scene == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_PLACE)
	_build_mode_controller.select_furniture_scene(kitchen_module_scene, &"kitchen_module", Vector2i(4, 2), true, 0)
	_update_detail_text("選択中: キッチンモジュール / 4 x 2 / Rで回転")


func _on_floor_place_pressed() -> void:
	_resolve_floor_placement()
	if _floor_placement == null or not _floor_placement.has_method("place_floor"):
		_update_detail_text("床モジュールが見つかりません")
		return
	var floor_node := _floor_placement.call("place_floor") as Node2D
	if floor_node == null:
		_update_detail_text("床を敷けませんでした: Floor_001.png を確認")
		return
	_update_detail_text("床を敷きました: Floor_001 / 15 x 15")
	_sync_floor_buttons()


func _on_floor_store_pressed() -> void:
	_resolve_floor_placement()
	if _floor_placement == null or not _floor_placement.has_method("remove_floor"):
		_update_detail_text("床モジュールが見つかりません")
		return
	var removed := bool(_floor_placement.call("remove_floor"))
	if removed:
		_update_detail_text("床をしまいました: Floor_001")
	else:
		_update_detail_text("しまう床がありません")
	_sync_floor_buttons()


func _on_build_mode_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		_update_category_detail_text()


func _on_tool_mode_changed(tool_mode: StringName) -> void:
	_sync_mode_buttons()
	match tool_mode:
		BuildModeController.TOOL_MODE_PLACE:
			_update_category_detail_text()
		BuildModeController.TOOL_MODE_MOVE:
			_update_detail_text("移動モード: 置いてある家具をクリック")
		BuildModeController.TOOL_MODE_STORE:
			_update_detail_text("しまうモード: 片付ける家具をクリック")


func _sync_visibility() -> void:
	if _build_mode_controller == null:
		visible = false
		return
	visible = _build_mode_controller.is_build_mode_enabled()


func _sync_mode_buttons() -> void:
	if _build_mode_controller == null:
		return
	var mode := _build_mode_controller.get_tool_mode()
	if place_mode_button != null:
		place_mode_button.button_pressed = mode == BuildModeController.TOOL_MODE_PLACE
	if move_mode_button != null:
		move_mode_button.button_pressed = mode == BuildModeController.TOOL_MODE_MOVE
	if store_mode_button != null:
		store_mode_button.button_pressed = mode == BuildModeController.TOOL_MODE_STORE


func _sync_category_buttons() -> void:
	_set_category_button_pressed(bedding_category_button, CATEGORY_BEDDING)
	_set_category_button_pressed(kitchen_category_button, CATEGORY_KITCHEN)
	_set_category_button_pressed(hygiene_category_button, CATEGORY_HYGIENE)
	_set_category_button_pressed(entertainment_category_button, CATEGORY_ENTERTAINMENT)
	_set_category_button_pressed(decor_category_button, CATEGORY_DECOR)
	_set_category_button_pressed(floor_category_button, CATEGORY_FLOOR)


func _set_category_button_pressed(button: Button, category_id: StringName) -> void:
	if button == null:
		return
	button.set_pressed_no_signal(_current_category_id == category_id)


func _sync_item_category_visibility() -> void:
	_set_button_visible(mattress_button, _current_category_id == CATEGORY_BEDDING)
	_set_button_visible(kitchen_module_button, _current_category_id == CATEGORY_KITCHEN)
	_set_button_visible(floor_place_button, _current_category_id == CATEGORY_FLOOR)
	_set_button_visible(floor_store_button, _current_category_id == CATEGORY_FLOOR)


func _set_button_visible(button: Button, should_show: bool) -> void:
	if button == null:
		return
	button.visible = should_show


func _sync_floor_buttons() -> void:
	var has_floor_module := _floor_placement != null
	var has_floor := false
	if has_floor_module and _floor_placement.has_method("has_floor"):
		has_floor = bool(_floor_placement.call("has_floor"))
	if floor_place_button != null:
		floor_place_button.disabled = not has_floor_module or has_floor
	if floor_store_button != null:
		floor_store_button.disabled = not has_floor_module or not has_floor


func _connect_controller_signals() -> void:
	if _build_mode_controller == null:
		return
	var build_callable := Callable(self, "_on_build_mode_changed")
	if not _build_mode_controller.build_mode_changed.is_connected(build_callable):
		_build_mode_controller.build_mode_changed.connect(build_callable)
	var mode_callable := Callable(self, "_on_tool_mode_changed")
	if not _build_mode_controller.tool_mode_changed.is_connected(mode_callable):
		_build_mode_controller.tool_mode_changed.connect(mode_callable)


func _resolve_controller() -> void:
	if _build_mode_controller != null:
		return
	if not build_mode_controller_path.is_empty():
		_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	if _build_mode_controller == null:
		_build_mode_controller = get_tree().get_first_node_in_group(&"build_mode_controller") as BuildModeController
	_connect_controller_signals()


func _resolve_floor_placement() -> void:
	if _floor_placement != null:
		return
	if not floor_placement_module_path.is_empty():
		_floor_placement = get_node_or_null(floor_placement_module_path)
	if _floor_placement == null:
		_floor_placement = get_tree().get_first_node_in_group(&"floor_placement_module")


func _normalize_category_id(category_id: StringName) -> StringName:
	match category_id:
		CATEGORY_BEDDING, CATEGORY_KITCHEN, CATEGORY_HYGIENE, CATEGORY_ENTERTAINMENT, CATEGORY_DECOR, CATEGORY_FLOOR:
			return category_id
		_:
			return CATEGORY_BEDDING


func _category_has_visible_items(category_id: StringName) -> bool:
	match category_id:
		CATEGORY_BEDDING, CATEGORY_KITCHEN, CATEGORY_FLOOR:
			return true
		_:
			return false


func _get_category_display_name(category_id: StringName) -> String:
	match category_id:
		CATEGORY_BEDDING:
			return "寝具"
		CATEGORY_KITCHEN:
			return "キッチン"
		CATEGORY_HYGIENE:
			return "衛生"
		CATEGORY_ENTERTAINMENT:
			return "娯楽"
		CATEGORY_DECOR:
			return "装飾"
		CATEGORY_FLOOR:
			return "床"
		_:
			return "寝具"


func _update_category_detail_text() -> void:
	var category_name := _get_category_display_name(_current_category_id)
	if _category_has_visible_items(_current_category_id):
		_update_detail_text("%sカテゴリ: 家具を選んでください" % category_name)
		return
	_update_detail_text("%sカテゴリにはまだ家具がありません" % category_name)


func _update_detail_text(message: String) -> void:
	if detail_label == null:
		return
	detail_label.text = message
