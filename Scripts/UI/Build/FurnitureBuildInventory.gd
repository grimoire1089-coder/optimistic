extends PanelContainer
class_name FurnitureBuildInventory

@export var build_mode_controller_path: NodePath = NodePath("../../BuildModeController")
@export var simple_mattress_scene: PackedScene

@onready var mattress_button: Button = $MarginContainer/Rows/ItemList/SimpleMattressButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _build_mode_controller: BuildModeController


func _ready() -> void:
	visible = false
	_resolve_controller()
	if mattress_button != null:
		mattress_button.pressed.connect(_on_simple_mattress_pressed)
	_connect_controller_signals()
	_sync_visibility()
	_update_detail_text("家具を選んでください")


func _process(_delta: float) -> void:
	_resolve_controller()
	_sync_visibility()


func _on_simple_mattress_pressed() -> void:
	_resolve_controller()
	if _build_mode_controller == null or simple_mattress_scene == null:
		return
	_build_mode_controller.select_furniture_scene(simple_mattress_scene, &"simple_mattress", Vector2i(4, 2))
	_update_detail_text("選択中: シンプルマットレス / 4 x 2")


func _on_build_mode_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		_update_detail_text("家具を選んでください")


func _sync_visibility() -> void:
	if _build_mode_controller == null:
		visible = false
		return
	visible = _build_mode_controller.is_build_mode_enabled()


func _connect_controller_signals() -> void:
	if _build_mode_controller == null:
		return
	var callable := Callable(self, "_on_build_mode_changed")
	if not _build_mode_controller.build_mode_changed.is_connected(callable):
		_build_mode_controller.build_mode_changed.connect(callable)


func _resolve_controller() -> void:
	if _build_mode_controller != null:
		return
	if build_mode_controller_path.is_empty():
		return
	_build_mode_controller = get_node_or_null(build_mode_controller_path) as BuildModeController
	_connect_controller_signals()


func _update_detail_text(message: String) -> void:
	if detail_label == null:
		return
	detail_label.text = message
