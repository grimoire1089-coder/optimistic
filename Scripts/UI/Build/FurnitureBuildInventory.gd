extends PanelContainer
class_name FurnitureBuildInventory

@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var simple_mattress_scene: PackedScene
@export var kitchen_module_scene: PackedScene

@onready var place_mode_button: Button = $MarginContainer/Rows/ModeButtons/PlaceModeButton
@onready var move_mode_button: Button = $MarginContainer/Rows/ModeButtons/MoveModeButton
@onready var store_mode_button: Button = $MarginContainer/Rows/ModeButtons/StoreModeButton
@onready var mattress_button: Button = $MarginContainer/Rows/ItemList/SimpleMattressButton
@onready var kitchen_module_button: Button = $MarginContainer/Rows/ItemList/KitchenModuleButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _build_mode_controller: BuildModeController


func _ready() -> void:
	visible = false
	_resolve_controller()
	_connect_buttons()
	_connect_controller_signals()
	_sync_visibility()
	_sync_mode_buttons()
	_update_detail_text("家具を選んでください")


func _process(_delta: float) -> void:
	_resolve_controller()
	_sync_visibility()
	_sync_mode_buttons()


func _connect_buttons() -> void:
	if place_mode_button != null:
		place_mode_button.pressed.connect(_on_place_mode_pressed)
	if move_mode_button != null:
		move_mode_button.pressed.connect(_on_move_mode_pressed)
	if store_mode_button != null:
		store_mode_button.pressed.connect(_on_store_mode_pressed)
	if mattress_button != null:
		mattress_button.pressed.connect(_on_simple_mattress_pressed)
	if kitchen_module_button != null:
		kitchen_module_button.pressed.connect(_on_kitchen_module_pressed)


func _on_place_mode_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null:
		return
	_build_mode_controller.set_tool_mode(BuildModeController.TOOL_MODE_PLACE)
	_update_detail_text("配置モード: 家具を選んでください")


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
	_build_mode_controller.select_furniture_scene(simple_mattress_scene, &"simple_mattress", Vector2i(2, 4), true, 0)
	_update_detail_text("選択中: シンプルマットレス / 2 x 4 / Rで回転")


func _on_kitchen_module_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null or kitchen_module_scene == null:
		return
	_build_mode_controller.select_furniture_scene(kitchen_module_scene, &"kitchen_module", Vector2i(4, 2), true, 0)
	_update_detail_text("選択中: キッチンモジュール / 4 x 2 / Rで回転")


func _on_build_mode_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		_update_detail_text("家具を選んでください")


func _on_tool_mode_changed(tool_mode: StringName) -> void:
	_sync_mode_buttons()
	match tool_mode:
		BuildModeController.TOOL_MODE_PLACE:
			_update_detail_text("配置モード: 家具を選んでください")
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


func _update_detail_text(message: String) -> void:
	if detail_label == null:
		return
	detail_label.text = message
