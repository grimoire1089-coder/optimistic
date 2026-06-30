extends PanelContainer
class_name FurnitureBuildInventory

@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var floor_placement_module_path: NodePath = NodePath("../../FloorPlacementModule")
@export var simple_mattress_scene: PackedScene
@export var kitchen_module_scene: PackedScene

@onready var place_mode_button: Button = $MarginContainer/Rows/ModeButtons/PlaceModeButton
@onready var move_mode_button: Button = $MarginContainer/Rows/ModeButtons/MoveModeButton
@onready var store_mode_button: Button = $MarginContainer/Rows/ModeButtons/StoreModeButton
@onready var mattress_button: Button = $MarginContainer/Rows/ItemList/SimpleMattressButton
@onready var kitchen_module_button: Button = $MarginContainer/Rows/ItemList/KitchenModuleButton
@onready var floor_place_button: Button = $MarginContainer/Rows/ItemList/FloorPlaceButton
@onready var floor_store_button: Button = $MarginContainer/Rows/ItemList/FloorStoreButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _build_mode_controller: BuildModeController
var _floor_placement: Node


func _ready() -> void:
	visible = false
	_resolve_controller()
	_resolve_floor_placement()
	_connect_buttons()
	_connect_controller_signals()
	_sync_visibility()
	_sync_mode_buttons()
	_sync_floor_buttons()
	_update_detail_text("家具を選んでください")


func _process(_delta: float) -> void:
	_resolve_controller()
	_resolve_floor_placement()
	_sync_visibility()
	_sync_mode_buttons()
	_sync_floor_buttons()


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
	if floor_place_button != null:
		floor_place_button.pressed.connect(_on_floor_place_pressed)
	if floor_store_button != null:
		floor_store_button.pressed.connect(_on_floor_store_pressed)


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


func _update_detail_text(message: String) -> void:
	if detail_label == null:
		return
	detail_label.text = message
