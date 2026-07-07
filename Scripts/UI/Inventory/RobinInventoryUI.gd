extends PanelContainer
class_name RobinInventoryUI

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const PANEL_SIZE := Vector2(480.0, 456.0)
const ITEM_ICON_SIZE := Vector2(64.0, 64.0)
const SLOTS_PER_PAGE := 20
const SORT_MODE_NAME: StringName = &"name"
const SORT_MODE_AMOUNT: StringName = &"amount"

@export var actor_path: NodePath = NodePath("../../Robin")
@export var inventory_module_child_name: StringName = &"RobinInventoryModule"
@export var slot_size: Vector2 = Vector2(72.0, 72.0)
@export var grid_columns: int = 5
@export_range(0, 24, 1) var grid_separation: int = 6

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var previous_page_button: Button = $MarginContainer/Rows/Header/PreviousPageButton
@onready var page_label: Label = $MarginContainer/Rows/Header/PageLabel
@onready var next_page_button: Button = $MarginContainer/Rows/Header/NextPageButton
@onready var tab_bar: TabBar = $MarginContainer/Rows/TabBar
@onready var grid: GridContainer = $MarginContainer/Rows/InventoryBody/ScrollContainer/Grid
@onready var sort_name_button: Button = $MarginContainer/Rows/InventoryBody/SortColumn/SortNameButton
@onready var sort_amount_button: Button = $MarginContainer/Rows/InventoryBody/SortColumn/SortAmountButton
@onready var detail_label: Label = $MarginContainer/Rows/Footer/DetailLabel
@onready var search_line_edit: LineEdit = $MarginContainer/Rows/Footer/SearchLineEdit

var _inventory_module: RobinInventoryModule
var _categories: Array[Dictionary] = []
var _current_category_index: int = 0
var _current_page_index: int = 0
var _search_query: String = ""
var _sort_mode: StringName = SORT_MODE_NAME


func _ready() -> void:
	visible = false
	add_to_group(&"inventory_ui")
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	close_button.pressed.connect(close)
	previous_page_button.pressed.connect(_on_previous_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	sort_name_button.pressed.connect(_on_sort_name_pressed)
	sort_amount_button.pressed.connect(_on_sort_amount_pressed)
	search_line_edit.text_changed.connect(_on_search_text_changed)
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
	var safe_columns: int = max(grid_columns, 1)
	grid.columns = safe_columns
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", grid_separation)
	grid.add_theme_constant_override("v_separation", grid_separation)
	_update_grid_minimum_size(SLOTS_PER_PAGE)
	_sync_sort_button_state()

	if _inventory_module == null:
		detail_label.text = "インベントリ未接続"
		_update_page_controls(0)
		return

	if _categories.is_empty():
		_setup_tabs()

	if _categories.is_empty():
		detail_label.text = "カテゴリがありません。"
		_update_page_controls(0)
		return

	var category := _categories[_current_category_index]
	var category_id := category.get("id", &"") as StringName
	var category_name := String(category.get("display_name", ""))
	var items := _inventory_module.get_items(category_id)
	var visible_items := _get_search_filtered_items(items)
	_sort_items(visible_items)
	var slot_limit := _inventory_module.get_slot_limit(category_id)
	var total_slot_count := _get_total_slot_count(slot_limit, visible_items.size(), _is_search_active())
	var page_count := _get_page_count(total_slot_count)
	_current_page_index = clampi(_current_page_index, 0, page_count - 1)
	_update_page_controls(total_slot_count)

	var start_index := _current_page_index * SLOTS_PER_PAGE
	for local_index in range(SLOTS_PER_PAGE):
		var slot_button := _create_slot_button()
		var item_index := start_index + local_index
		if item_index < visible_items.size():
			_apply_item_to_slot(slot_button, visible_items[item_index] as Dictionary)
		else:
			slot_button.text = ""
		grid.add_child(slot_button)

	detail_label.text = _build_detail_text(category_name, items.size(), visible_items.size(), slot_limit)


func _create_slot_button() -> Button:
	var slot_button := Button.new()
	slot_button.custom_minimum_size = slot_size
	slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot_button.focus_mode = Control.FOCUS_NONE
	slot_button.clip_text = true
	slot_button.expand_icon = false
	slot_button.clip_contents = true
	slot_button.add_child(_create_item_icon_rect())
	return slot_button


func _create_item_icon_rect() -> TextureRect:
	var icon_rect := TextureRect.new()
	icon_rect.name = "ItemIcon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = ITEM_ICON_SIZE
	icon_rect.anchor_left = 0.5
	icon_rect.anchor_top = 0.5
	icon_rect.anchor_right = 0.5
	icon_rect.anchor_bottom = 0.5
	icon_rect.offset_left = -ITEM_ICON_SIZE.x * 0.5
	icon_rect.offset_top = -ITEM_ICON_SIZE.y * 0.5
	icon_rect.offset_right = ITEM_ICON_SIZE.x * 0.5
	icon_rect.offset_bottom = ITEM_ICON_SIZE.y * 0.5
	return icon_rect


func _apply_item_to_slot(slot_button: Button, item: Dictionary) -> void:
	var display_name := String(item.get("display_name", ""))
	var amount := int(item.get("amount", 1))
	slot_button.text = ""
	slot_button.tooltip_text = _build_item_tooltip(display_name, amount)

	var icon_rect := slot_button.get_node_or_null("ItemIcon") as TextureRect
	var icon_path := String(item.get("icon_path", ""))
	if icon_rect != null:
		icon_rect.texture = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path) as Texture2D

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


func _get_search_filtered_items(items: Array[Dictionary]) -> Array[Dictionary]:
	if not _is_search_active():
		return items
	var result: Array[Dictionary] = []
	var query := _search_query.to_lower()
	for item in items:
		if _item_matches_search(item, query):
			result.append(item)
	return result


func _item_matches_search(item: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	var display_name := String(item.get("display_name", "")).to_lower()
	if display_name.contains(query):
		return true
	var item_id := String(item.get("id", &"")).to_lower()
	if item_id.contains(query):
		return true
	var description := String(item.get("description", "")).to_lower()
	return description.contains(query)


func _sort_items(items: Array[Dictionary]) -> void:
	match _sort_mode:
		SORT_MODE_AMOUNT:
			items.sort_custom(_compare_items_by_amount)
		_:
			items.sort_custom(_compare_items_by_name)


func _compare_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	var a_name := String(a.get("display_name", "")).to_lower()
	var b_name := String(b.get("display_name", "")).to_lower()
	if a_name == b_name:
		return String(a.get("id", &"")).to_lower() < String(b.get("id", &"")).to_lower()
	return a_name < b_name


func _compare_items_by_amount(a: Dictionary, b: Dictionary) -> bool:
	var a_amount := int(a.get("amount", 0))
	var b_amount := int(b.get("amount", 0))
	if a_amount == b_amount:
		return _compare_items_by_name(a, b)
	return a_amount > b_amount


func _is_search_active() -> bool:
	return not _search_query.is_empty()


func _get_total_slot_count(slot_limit: int, item_count: int, search_active: bool) -> int:
	if search_active:
		return max(item_count, SLOTS_PER_PAGE)
	if slot_limit == RobinInventoryModule.UNLIMITED_SLOT_LIMIT:
		return max(item_count, _inventory_module.get_slots_per_category(), SLOTS_PER_PAGE)
	return max(slot_limit, item_count, SLOTS_PER_PAGE)


func _get_page_count(total_slot_count: int) -> int:
	return max(ceili(float(max(total_slot_count, 1)) / float(SLOTS_PER_PAGE)), 1)


func _update_page_controls(total_slot_count: int) -> void:
	var page_count := _get_page_count(total_slot_count)
	var has_multiple_pages := page_count > 1
	previous_page_button.visible = has_multiple_pages
	page_label.visible = has_multiple_pages
	next_page_button.visible = has_multiple_pages
	previous_page_button.disabled = _current_page_index <= 0
	next_page_button.disabled = _current_page_index >= page_count - 1
	page_label.text = "%d/%d" % [_current_page_index + 1, page_count]


func _sync_sort_button_state() -> void:
	sort_name_button.set_pressed_no_signal(_sort_mode == SORT_MODE_NAME)
	sort_amount_button.set_pressed_no_signal(_sort_mode == SORT_MODE_AMOUNT)


func _update_grid_minimum_size(slot_count: int) -> void:
	var safe_columns: int = max(grid_columns, 1)
	var visible_rows: int = max(ceili(float(max(slot_count, 1)) / float(safe_columns)), 1)
	grid.custom_minimum_size = Vector2(
		float(safe_columns) * slot_size.x + float(max(safe_columns - 1, 0) * grid_separation),
		float(visible_rows) * slot_size.y + float(max(visible_rows - 1, 0) * grid_separation)
	)


func _build_detail_text(category_name: String, item_count: int, visible_item_count: int, slot_limit: int) -> String:
	if _is_search_active():
		return "%s  検索 %d/%d" % [category_name, visible_item_count, item_count]
	if slot_limit == RobinInventoryModule.UNLIMITED_SLOT_LIMIT:
		return "%s  %d/無制限" % [category_name, item_count]
	return "%s  %d/%d" % [category_name, item_count, slot_limit]


func _clear_grid() -> void:
	for child in grid.get_children():
		child.queue_free()


func _on_tab_changed(tab_index: int) -> void:
	_current_category_index = tab_index
	_current_page_index = 0
	_refresh()


func _on_search_text_changed(new_text: String) -> void:
	_search_query = new_text.strip_edges()
	_current_page_index = 0
	_refresh()


func _on_sort_name_pressed() -> void:
	_sort_mode = SORT_MODE_NAME
	_current_page_index = 0
	_refresh()


func _on_sort_amount_pressed() -> void:
	_sort_mode = SORT_MODE_AMOUNT
	_current_page_index = 0
	_refresh()


func _on_previous_page_pressed() -> void:
	_current_page_index = max(_current_page_index - 1, 0)
	_refresh()


func _on_next_page_pressed() -> void:
	_current_page_index += 1
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
