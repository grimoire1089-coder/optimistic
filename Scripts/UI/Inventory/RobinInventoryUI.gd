extends PanelContainer
class_name RobinInventoryUI

@export var actor_path: NodePath = NodePath("../../Robin")
@export var inventory_module_child_name: StringName = &"RobinInventoryModule"
@export var slot_size: Vector2 = Vector2(72, 72)
@export var grid_columns: int = 5

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var tab_bar: TabBar = $MarginContainer/Rows/TabBar
@onready var grid: GridContainer = $MarginContainer/Rows/ScrollContainer/Grid
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _inventory_module: RobinInventoryModule
var _categories: Array[Dictionary] = []
var _current_category_index: int = 0


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_resolve_inventory_module()
	_setup_tabs()
	_refresh()


func open() -> void:
	visible = true
	_resolve_inventory_module()
	_refresh()


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_resolve_inventory_module()
		_refresh()


func toggle_inventory() -> void:
	toggle()


func _resolve_inventory_module() -> void:
	if _inventory_module != null and is_instance_valid(_inventory_module):
		return

	var actor := get_node_or_null(actor_path)
	if actor == null:
		push_warning("ロビンが見つかりません: %s" % actor_path)
		return

	if actor.has_method("get_inventory_module"):
		_inventory_module = actor.call("get_inventory_module") as RobinInventoryModule
	else:
		_inventory_module = actor.get_node_or_null(NodePath(String(inventory_module_child_name))) as RobinInventoryModule

	if _inventory_module == null:
		push_warning("ロビンのインベントリモジュールが見つかりません。")
		return

	if not _inventory_module.inventory_changed.is_connected(_refresh):
		_inventory_module.inventory_changed.connect(_refresh)


func _setup_tabs() -> void:
	tab_bar.clear_tabs()
	_categories.clear()

	if _inventory_module == null:
		return

	_categories = _inventory_module.get_categories()
	for category in _categories:
		tab_bar.add_tab(String(category.get("display_name", "Tab")))

	_current_category_index = clampi(_current_category_index, 0, max(_categories.size() - 1, 0))
	if _categories.size() > 0:
		tab_bar.current_tab = _current_category_index


func _refresh() -> void:
	_clear_grid()
	title_label.text = "ロビンのインベントリ"
	grid.columns = max(grid_columns, 1)

	if _inventory_module == null:
		detail_label.text = "インベントリ未接続"
		return

	if _categories.is_empty():
		_setup_tabs()

	if _categories.is_empty():
		detail_label.text = "カテゴリがありません。"
		return

	var category := _categories[_current_category_index]
	var category_id := category.get("id", &"") as StringName
	var category_name := String(category.get("display_name", ""))
	var items := _inventory_module.get_items(category_id)
	var slot_count := _inventory_module.get_slots_per_category()

	for index in range(slot_count):
		var slot_button := _create_slot_button()
		if index < items.size():
			_apply_item_to_slot(slot_button, items[index] as Dictionary)
		else:
			slot_button.text = ""
		grid.add_child(slot_button)

	detail_label.text = "%s  %d/%d" % [category_name, items.size(), slot_count]


func _create_slot_button() -> Button:
	var slot_button := Button.new()
	slot_button.custom_minimum_size = slot_size
	slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot_button.focus_mode = Control.FOCUS_NONE
	slot_button.clip_text = true
	slot_button.expand_icon = true
	return slot_button


func _apply_item_to_slot(slot_button: Button, item: Dictionary) -> void:
	var display_name := String(item.get("display_name", ""))
	var amount := int(item.get("amount", 1))
	if amount > 1:
		slot_button.text = "%s\nx%d" % [display_name, amount]
	else:
		slot_button.text = display_name

	var icon_path := String(item.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		slot_button.icon = load(icon_path) as Texture2D


func _clear_grid() -> void:
	for child in grid.get_children():
		child.queue_free()


func _on_tab_changed(tab_index: int) -> void:
	_current_category_index = tab_index
	_refresh()
