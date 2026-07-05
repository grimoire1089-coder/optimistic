extends PanelContainer
class_name RobinInventoryUI

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const PANEL_SIZE := Vector2(436.0, 420.0)

@export var actor_path: NodePath = NodePath("../../Robin")
@export var inventory_module_child_name: StringName = &"RobinInventoryModule"
@export var slot_size: Vector2 = Vector2(68, 68)
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
	add_to_group(&"inventory_ui")
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	close_button.pressed.connect(close)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_resolve_inventory_module()
	_setup_tabs()
	_refresh()


func open() -> void:
	_apply_bottom_right_layout()
	visible = true
	_resolve_inventory_module()
	_refresh()


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_apply_bottom_right_layout()
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
	var slot_limit := _inventory_module.get_slot_limit(category_id)
	var slot_count := _get_visible_slot_count(slot_limit, items.size())

	for index in range(slot_count):
		var slot_button := _create_slot_button()
		if index < items.size():
			_apply_item_to_slot(slot_button, items[index] as Dictionary)
		else:
			slot_button.text = ""
		grid.add_child(slot_button)

	detail_label.text = _build_detail_text(category_name, items.size(), slot_limit)


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
	slot_button.text = ""
	slot_button.tooltip_text = _build_item_tooltip(display_name, amount)

	var icon_path := String(item.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		slot_button.icon = load(icon_path) as Texture2D

	_add_amount_badge(slot_button, amount)


func _build_item_tooltip(display_name: String, amount: int) -> String:
	if display_name.is_empty():
		return "x%d" % max(amount, 1)
	return "%s x%d" % [display_name, max(amount, 1)]


func _add_amount_badge(slot_button: Button, amount: int) -> void:
	var badge := Label.new()
	badge.name = "AmountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(max(amount, 1))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.anchor_left = 1.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -28.0
	badge.offset_top = -22.0
	badge.offset_right = -3.0
	badge.offset_bottom = -3.0
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_stylebox_override("normal", _make_amount_badge_style())
	slot_button.add_child(badge)


func _make_amount_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.14, 0.8, 0.95, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(1.0)
	return style


func _get_visible_slot_count(slot_limit: int, item_count: int) -> int:
	if slot_limit == RobinInventoryModule.UNLIMITED_SLOT_LIMIT:
		return max(item_count, _inventory_module.get_slots_per_category())
	return slot_limit


func _build_detail_text(category_name: String, item_count: int, slot_limit: int) -> String:
	if slot_limit == RobinInventoryModule.UNLIMITED_SLOT_LIMIT:
		return "%s  %d/無制限" % [category_name, item_count]
	return "%s  %d/%d" % [category_name, item_count, slot_limit]


func _clear_grid() -> void:
	for child in grid.get_children():
		child.queue_free()


func _on_tab_changed(tab_index: int) -> void:
	_current_category_index = tab_index
	_refresh()


func _apply_bottom_right_layout() -> void:
	custom_minimum_size = PANEL_SIZE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -BOTTOM_RIGHT_MARGIN.x - PANEL_SIZE.x
	offset_top = -BOTTOM_RIGHT_MARGIN.y - PANEL_SIZE.y
	offset_right = -BOTTOM_RIGHT_MARGIN.x
	offset_bottom = -BOTTOM_RIGHT_MARGIN.y
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
