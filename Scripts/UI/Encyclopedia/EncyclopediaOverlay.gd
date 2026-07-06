extends Control
class_name EncyclopediaOverlay

const DEFAULT_ENCYCLOPEDIA_BGM_PATH := "res://Assets/Audio/BGM/Picture book.ogg"
const DEFAULT_UNKNOWN_ICON_PATH := "res://Assets/UI/Icons/Question.png"
const UNKNOWN_DISPLAY_NAME := "？？？"
const CATEGORY_TAB_MODULE_SCRIPT_PATH := "res://Scripts/UI/Encyclopedia/Modules/EncyclopediaCategoryTabModule.gd"

const CATEGORY_FOODS := "foods"
const CATEGORY_TOOLS := "tools"
const CATEGORY_DRINKS := "drinks"
const CATEGORY_INGREDIENTS := "ingredients"
const FALLBACK_CATEGORY_IDS := [CATEGORY_FOODS, CATEGORY_TOOLS, CATEGORY_DRINKS, CATEGORY_INGREDIENTS]

const DEFAULT_FOOD_ITEM_PATHS := [
	"res://Data/Items/Food/Food_0001_Nikuman.tres",
	"res://Data/Items/Food/Food_0016_FelicityClassicBurger.tres",
	"res://Data/Items/Food/Food_0013_WhiteRice.tres",
]
const DEFAULT_TOOL_ITEM_PATHS := [
	"res://Data/Items/Tools/Lapis_001.tres",
]
const DEFAULT_DRINK_ITEM_PATHS := [
	"res://Data/Items/Food/Drink_1001_LycheeSoda.tres",
	"res://Data/Items/Food/Drink_1002_OolongTea.tres",
	"res://Data/Items/Food/Food_0008_WaterBottle.tres",
]
const DEFAULT_INGREDIENT_ITEM_PATHS := [
	"res://Data/Items/Ingredients/Ingredients_0001_RawRice.tres",
	"res://Data/Items/Ingredients/Ingredients_0002_WheatFlour.tres",
	"res://Data/Items/Ingredients/Ingredients_0003_WhiteSugar.tres",
	"res://Data/Items/Ingredients/Ingredients_0004_Salt.tres",
	"res://Data/Items/Ingredients/Ingredients_0005_PinkRockSalt.tres",
]

const ITEM_ROW_HEIGHT := 76.0
const ITEM_ICON_FRAME_SIZE := Vector2(72.0, 72.0)
const ITEM_ICON_SIZE := Vector2(64.0, 64.0)

@export var category_tabs_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs")
@export var close_button_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/Header/CloseButton")
@export var food_item_paths: PackedStringArray = PackedStringArray(DEFAULT_FOOD_ITEM_PATHS)
@export var tool_item_paths: PackedStringArray = PackedStringArray(DEFAULT_TOOL_ITEM_PATHS)
@export var drink_item_paths: PackedStringArray = PackedStringArray(DEFAULT_DRINK_ITEM_PATHS)
@export var ingredient_item_paths: PackedStringArray = PackedStringArray(DEFAULT_INGREDIENT_ITEM_PATHS)
@export var unknown_icon: Texture2D
@export var unknown_icon_path: String = DEFAULT_UNKNOWN_ICON_PATH
@export var encyclopedia_bgm: AudioStream
@export var encyclopedia_bgm_path: String = DEFAULT_ENCYCLOPEDIA_BGM_PATH
@export var restore_previous_bgm: bool = true
@export var pause_scene_tree: bool = true
@export var pause_game_clock: bool = true

var _category_tabs: TabContainer
var _close_button: Button
var _category_tab_module: Node
var _game_clock: Node
var _item_rows_by_category: Dictionary = {}
var _detail_icon_by_category: Dictionary = {}
var _detail_name_label_by_category: Dictionary = {}
var _detail_description_label_by_category: Dictionary = {}
var _detail_meta_label_by_category: Dictionary = {}
var _entries_by_category: Dictionary = {}
var _row_buttons_by_category: Dictionary = {}
var _selected_index_by_category: Dictionary = {}
var _previous_bgm: AudioStream
var _previous_bgm_position: float = 0.0
var _has_previous_bgm: bool = false
var _active_encyclopedia_bgm: AudioStream
var _was_tree_paused: bool = false
var _has_saved_tree_pause: bool = false
var _was_clock_paused: bool = false
var _has_saved_clock_pause: bool = false


func _ready() -> void:
	add_to_group("encyclopedia_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_process_mode_recursive(self, Node.PROCESS_MODE_ALWAYS)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_get_category_tab_module()
	_resolve_refs()
	_load_unknown_icon_if_needed()
	_load_default_encyclopedia_bgm_if_needed()
	_connect_food_encyclopedia_signal()
	_apply_visual_theme()
	_setup_tabs()
	_connect_close_button()
	_populate_all_category_entries()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_encyclopedia()
		get_viewport().set_input_as_handled()


func open_encyclopedia() -> void:
	if visible:
		return

	_resolve_refs()
	_load_unknown_icon_if_needed()
	_connect_food_encyclopedia_signal()
	_save_pause_state()
	visible = true
	move_to_front()
	_pause_game()
	_play_encyclopedia_bgm()
	_populate_all_category_entries()

	var selected_row := _get_selected_row(_get_active_category_id())
	if selected_row != null:
		selected_row.grab_focus()


func close_encyclopedia() -> void:
	if not visible:
		return

	visible = false
	_restore_previous_bgm_if_needed()
	_restore_pause_state()


func toggle_encyclopedia() -> void:
	if visible:
		close_encyclopedia()
	else:
		open_encyclopedia()


func _exit_tree() -> void:
	if visible:
		_restore_previous_bgm_if_needed()
		_restore_pause_state()


func _resolve_refs() -> void:
	if _category_tabs == null and not category_tabs_path.is_empty():
		_category_tabs = get_node_or_null(category_tabs_path) as TabContainer
	if _close_button == null and not close_button_path.is_empty():
		_close_button = get_node_or_null(close_button_path) as Button

	for category_id in _get_category_ids():
		var item_rows := get_node_or_null(_make_category_node_path(category_id, "ListPanel/ListMargin/ListRows/ItemScroll/ItemRows")) as VBoxContainer
		if item_rows != null:
			_item_rows_by_category[category_id] = item_rows

		var detail_icon := get_node_or_null(_make_category_node_path(category_id, "DetailPanel/DetailMargin/DetailScroll/DetailRows/DetailIcon")) as TextureRect
		if detail_icon != null:
			_detail_icon_by_category[category_id] = detail_icon

		var detail_name_label := get_node_or_null(_make_category_node_path(category_id, "DetailPanel/DetailMargin/DetailScroll/DetailRows/DetailNameLabel")) as Label
		if detail_name_label != null:
			_detail_name_label_by_category[category_id] = detail_name_label

		var detail_description_label := get_node_or_null(_make_category_node_path(category_id, "DetailPanel/DetailMargin/DetailScroll/DetailRows/DetailDescriptionLabel")) as RichTextLabel
		if detail_description_label != null:
			_detail_description_label_by_category[category_id] = detail_description_label

		var detail_meta_label := get_node_or_null(_make_category_node_path(category_id, "DetailPanel/DetailMargin/DetailScroll/DetailRows/DetailMetaLabel")) as Label
		if detail_meta_label != null:
			_detail_meta_label_by_category[category_id] = detail_meta_label


func _setup_tabs() -> void:
	if _category_tabs == null:
		return

	var category_ids := _get_category_ids()
	var tab_count := mini(_category_tabs.get_tab_count(), category_ids.size())
	for index in range(tab_count):
		_category_tabs.set_tab_title(index, _get_category_tab_title(category_ids[index]))

	var callable := Callable(self, "_on_category_tab_changed")
	if not _category_tabs.tab_changed.is_connected(callable):
		_category_tabs.tab_changed.connect(callable)


func _connect_close_button() -> void:
	if _close_button == null:
		return
	if not _close_button.pressed.is_connected(close_encyclopedia):
		_close_button.pressed.connect(close_encyclopedia)


func _connect_food_encyclopedia_signal() -> void:
	var encyclopedia := get_node_or_null("/root/FoodEncyclopedia")
	if encyclopedia == null:
		return
	var callable := Callable(self, "_on_food_encyclopedia_changed")
	if encyclopedia.has_signal("encyclopedia_changed") and not encyclopedia.is_connected("encyclopedia_changed", callable):
		encyclopedia.connect("encyclopedia_changed", callable)


func _on_food_encyclopedia_changed() -> void:
	_populate_all_category_entries()


func _on_category_tab_changed(_tab: int) -> void:
	var selected_row := _get_selected_row(_get_active_category_id())
	if selected_row != null:
		selected_row.grab_focus()


func _populate_all_category_entries() -> void:
	for category_id in _get_category_ids():
		_populate_category_entries(category_id)


func _populate_category_entries(category_id: String) -> void:
	var item_rows := _get_item_rows(category_id)
	if item_rows == null:
		return

	var entries: Array = []
	var row_buttons: Array = []
	_entries_by_category[category_id] = entries
	_row_buttons_by_category[category_id] = row_buttons
	_clear_category_rows(category_id)

	for item_path in _get_item_paths_for_category(category_id):
		var entry := _make_item_entry(String(item_path), category_id)
		if entry.is_empty():
			continue
		entries.append(entry)
		var row := _make_item_row(category_id, entry, entries.size() - 1)
		item_rows.add_child(row)
		row_buttons.append(row)

	if entries.size() > 0:
		var selected_index := clampi(int(_selected_index_by_category.get(category_id, 0)), 0, entries.size() - 1)
		_select_entry(category_id, selected_index)
	else:
		_selected_index_by_category[category_id] = -1
		_show_empty_detail(category_id)


func _clear_category_rows(category_id: String) -> void:
	var item_rows := _get_item_rows(category_id)
	if item_rows == null:
		return
	for child in item_rows.get_children():
		item_rows.remove_child(child)
		child.queue_free()


func _make_item_row(category_id: String, entry: Dictionary, index: int) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0.0, ITEM_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.text = ""
	row.tooltip_text = _get_entry_tooltip(entry)
	row.pressed.connect(Callable(self, "_on_item_row_pressed").bind(category_id, index))
	_apply_item_row_style(row, false)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = ITEM_ICON_FRAME_SIZE
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", _make_style(Color(0.020, 0.026, 0.032, 0.98), Color(0.0, 1.2, 1.2, 0.95), 4, 10, 4.0))
	hbox.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_theme_constant_override("margin_left", 4)
	icon_margin.add_theme_constant_override("margin_top", 4)
	icon_margin.add_theme_constant_override("margin_right", 4)
	icon_margin.add_theme_constant_override("margin_bottom", 4)
	icon_frame.add_child(icon_margin)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ITEM_ICON_SIZE
	icon.texture = _get_entry_icon(entry)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(icon)

	var name_frame := PanelContainer.new()
	name_frame.custom_minimum_size = Vector2(0.0, ITEM_ICON_FRAME_SIZE.y)
	name_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_frame.add_theme_stylebox_override("panel", _make_style(Color(0.090, 0.095, 0.112, 0.86), Color(0.14, 0.34, 0.38, 0.62), 1, 8, 8.0))
	hbox.add_child(name_frame)

	var name_margin := MarginContainer.new()
	name_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_margin.add_theme_constant_override("margin_left", 14)
	name_margin.add_theme_constant_override("margin_top", 6)
	name_margin.add_theme_constant_override("margin_right", 14)
	name_margin.add_theme_constant_override("margin_bottom", 6)
	name_frame.add_child(name_margin)

	var name_label := Label.new()
	name_label.text = _get_entry_display_name(entry)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	name_label.add_theme_font_size_override("font_size", 16)
	name_margin.add_child(name_label)

	return row


func _on_item_row_pressed(category_id: String, index: int) -> void:
	_select_entry(category_id, index)


func _select_entry(category_id: String, index: int) -> void:
	var entries: Array = _entries_by_category.get(category_id, [])
	if index < 0 or index >= entries.size():
		return
	_selected_index_by_category[category_id] = index

	var row_buttons: Array = _row_buttons_by_category.get(category_id, [])
	for row_index in range(row_buttons.size()):
		var row := row_buttons[row_index] as Button
		_apply_item_row_style(row, row_index == index)
	_show_entry(category_id, entries[index] as Dictionary)


func _get_selected_row(category_id: String) -> Button:
	var selected_index := int(_selected_index_by_category.get(category_id, -1))
	var row_buttons: Array = _row_buttons_by_category.get(category_id, [])
	if selected_index < 0 or selected_index >= row_buttons.size():
		return null
	return row_buttons[selected_index] as Button


func _apply_item_row_style(row: Button, is_selected: bool) -> void:
	if row == null:
		return
	if is_selected:
		row.add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.11, 0.14, 0.72), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
		row.add_theme_stylebox_override("hover", _make_style(Color(0.13, 0.14, 0.17, 0.82), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
		row.add_theme_stylebox_override("pressed", _make_style(Color(0.07, 0.18, 0.20, 0.86), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
		row.add_theme_stylebox_override("focus", _make_style(Color(0.10, 0.11, 0.14, 0.72), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
		return
	row.add_theme_stylebox_override("normal", _make_style(Color(0.05, 0.055, 0.065, 0.48), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
	row.add_theme_stylebox_override("hover", _make_style(Color(0.08, 0.09, 0.105, 0.66), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
	row.add_theme_stylebox_override("pressed", _make_style(Color(0.07, 0.16, 0.18, 0.78), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))
	row.add_theme_stylebox_override("focus", _make_style(Color(0.08, 0.09, 0.105, 0.66), Color(0.0, 0.0, 0.0, 0.0), 0, 9, 2.0))


func _make_item_entry(item_path: String, fallback_category_id: String) -> Dictionary:
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		return {}
	var resource := load(item_path)
	if resource == null:
		return {}

	var display_name := String(resource.get("display_name"))
	if display_name.is_empty():
		display_name = item_path.get_file().get_basename()

	var category_id := String(resource.get("category_id"))
	if category_id.is_empty():
		category_id = fallback_category_id

	return {
		"path": item_path,
		"item_id": resource.get("item_id"),
		"display_name": display_name,
		"description": String(resource.get("description")),
		"icon": resource.get("icon") as Texture2D,
		"category_id": category_id,
		"buy_price": int(resource.get("buy_price")),
		"sell_price": int(resource.get("sell_price")),
	}


func _show_entry(category_id: String, entry: Dictionary) -> void:
	if not _is_entry_unlocked(entry):
		_show_locked_entry(category_id)
		return
	var detail_icon := _get_detail_icon(category_id)
	if detail_icon != null:
		detail_icon.texture = entry.get("icon") as Texture2D
	var detail_name_label := _get_detail_name_label(category_id)
	if detail_name_label != null:
		detail_name_label.text = String(entry.get("display_name", "未登録アイテム"))
	var detail_description_label := _get_detail_description_label(category_id)
	if detail_description_label != null:
		detail_description_label.text = String(entry.get("description", "まだ説明が登録されていません。"))
	var detail_meta_label := _get_detail_meta_label(category_id)
	if detail_meta_label != null:
		detail_meta_label.text = _make_meta_text(entry)


func _show_locked_entry(category_id: String) -> void:
	var detail_icon := _get_detail_icon(category_id)
	if detail_icon != null:
		detail_icon.texture = unknown_icon
	var detail_name_label := _get_detail_name_label(category_id)
	if detail_name_label != null:
		detail_name_label.text = UNKNOWN_DISPLAY_NAME
	var detail_description_label := _get_detail_description_label(category_id)
	if detail_description_label != null:
		detail_description_label.text = "まだ図鑑に登録されていません。インベントリに一度入手すると解放されます。"
	var detail_meta_label := _get_detail_meta_label(category_id)
	if detail_meta_label != null:
		detail_meta_label.text = "未解放"


func _show_empty_detail(category_id: String) -> void:
	var detail_icon := _get_detail_icon(category_id)
	if detail_icon != null:
		detail_icon.texture = unknown_icon
	var detail_name_label := _get_detail_name_label(category_id)
	if detail_name_label != null:
		detail_name_label.text = _get_category_empty_name(category_id)
	var detail_description_label := _get_detail_description_label(category_id)
	if detail_description_label != null:
		detail_description_label.text = _get_category_empty_description(category_id)
	var detail_meta_label := _get_detail_meta_label(category_id)
	if detail_meta_label != null:
		detail_meta_label.text = "カテゴリ：%s / 登録数：0" % _get_category_display_name(category_id)


func _get_entry_display_name(entry: Dictionary) -> String:
	if not _is_entry_unlocked(entry):
		return UNKNOWN_DISPLAY_NAME
	return String(entry.get("display_name", "未登録アイテム"))


func _get_entry_icon(entry: Dictionary) -> Texture2D:
	if not _is_entry_unlocked(entry):
		return unknown_icon
	return entry.get("icon") as Texture2D


func _get_entry_tooltip(entry: Dictionary) -> String:
	if not _is_entry_unlocked(entry):
		return "未解放"
	return String(entry.get("description", ""))


func _is_entry_unlocked(entry: Dictionary) -> bool:
	var item_id := _get_entry_item_id(entry)
	if item_id == &"":
		return false
	var encyclopedia := get_node_or_null("/root/FoodEncyclopedia")
	if encyclopedia == null or not encyclopedia.has_method("is_item_unlocked"):
		return false
	return encyclopedia.call("is_item_unlocked", item_id) == true


func _get_entry_item_id(entry: Dictionary) -> StringName:
	var raw_id: Variant = entry.get("item_id", &"")
	if raw_id is StringName:
		return raw_id
	return StringName(String(raw_id))


func _make_meta_text(entry: Dictionary) -> String:
	var category_name := _get_category_display_name(String(entry.get("category_id", CATEGORY_FOODS)))
	var buy_price := int(entry.get("buy_price", 0))
	var sell_price := int(entry.get("sell_price", 0))
	return "カテゴリ：%s / 購入：%d CR / 売却：%d CR" % [category_name, buy_price, sell_price]


func _get_category_display_name(category_id: String) -> String:
	return _get_category_tab_title(category_id)


func _get_category_ids() -> Array[String]:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_category_ids"):
		var raw_ids: Array = module.call("get_category_ids")
		var result: Array[String] = []
		for raw_id in raw_ids:
			var category_id := String(raw_id)
			if not category_id.is_empty():
				result.append(category_id)
		if not result.is_empty():
			return result

	var fallback: Array[String] = []
	for raw_id in FALLBACK_CATEGORY_IDS:
		fallback.append(String(raw_id))
	return fallback


func _get_category_tab_title(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_tab_title"):
		return String(module.call("get_tab_title", category_id))
	match category_id:
		CATEGORY_FOODS:
			return "食品"
		CATEGORY_TOOLS:
			return "ツール"
		CATEGORY_DRINKS:
			return "飲料"
		CATEGORY_INGREDIENTS:
			return "食材"
		_:
			return category_id


func _get_category_page_name(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_page_name"):
		return String(module.call("get_page_name", category_id))
	match category_id:
		CATEGORY_FOODS:
			return "FoodPage"
		CATEGORY_TOOLS:
			return "ToolPage"
		CATEGORY_DRINKS:
			return "DrinkPage"
		CATEGORY_INGREDIENTS:
			return "IngredientPage"
		_:
			return ""


func _get_category_hint(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_tab_hint"):
		return String(module.call("get_tab_hint", category_id))
	return "図鑑ページ。"


func _get_category_empty_name(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_empty_name"):
		return String(module.call("get_empty_name", category_id))
	return "%sテンプレート" % _get_category_tab_title(category_id)


func _get_category_empty_description(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_empty_description"):
		return String(module.call("get_empty_description", category_id))
	return "図鑑テンプレートです。"


func _get_category_flavor_text(category_id: String) -> String:
	var module := _get_category_tab_module()
	if module != null and module.has_method("get_flavor_text"):
		return String(module.call("get_flavor_text", category_id))
	return "デカダンス生活図鑑の記録。"


func _get_active_category_id() -> String:
	if _category_tabs == null:
		return CATEGORY_FOODS
	var category_ids := _get_category_ids()
	var current_tab := _category_tabs.current_tab
	if current_tab < 0 or current_tab >= category_ids.size():
		return CATEGORY_FOODS
	return category_ids[current_tab]


func _get_item_paths_for_category(category_id: String) -> PackedStringArray:
	match category_id:
		CATEGORY_FOODS:
			return food_item_paths
		CATEGORY_TOOLS:
			return tool_item_paths
		CATEGORY_DRINKS:
			return drink_item_paths
		CATEGORY_INGREDIENTS:
			return ingredient_item_paths
		_:
			return PackedStringArray()


func _make_category_node_path(category_id: String, relative_path: String) -> NodePath:
	var page_name := _get_category_page_name(category_id)
	if page_name.is_empty() or relative_path.is_empty():
		return NodePath("")
	return NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/%s/%s" % [page_name, relative_path])


func _get_item_rows(category_id: String) -> VBoxContainer:
	return _item_rows_by_category.get(category_id) as VBoxContainer


func _get_detail_icon(category_id: String) -> TextureRect:
	return _detail_icon_by_category.get(category_id) as TextureRect


func _get_detail_name_label(category_id: String) -> Label:
	return _detail_name_label_by_category.get(category_id) as Label


func _get_detail_description_label(category_id: String) -> RichTextLabel:
	return _detail_description_label_by_category.get(category_id) as RichTextLabel


func _get_detail_meta_label(category_id: String) -> Label:
	return _detail_meta_label_by_category.get(category_id) as Label


func _get_category_tab_module() -> Node:
	if _category_tab_module != null and is_instance_valid(_category_tab_module):
		return _category_tab_module
	if not ResourceLoader.exists(CATEGORY_TAB_MODULE_SCRIPT_PATH):
		return null
	var script := load(CATEGORY_TAB_MODULE_SCRIPT_PATH) as Script
	if script == null:
		return null
	var module := script.new() as Node
	if module == null:
		return null
	module.name = "EncyclopediaCategoryTabModule"
	add_child(module)
	_category_tab_module = module
	return _category_tab_module


func _load_unknown_icon_if_needed() -> void:
	if unknown_icon != null:
		return
	if unknown_icon_path.is_empty():
		return
	if ResourceLoader.exists(unknown_icon_path):
		unknown_icon = load(unknown_icon_path) as Texture2D


func _load_default_encyclopedia_bgm_if_needed() -> void:
	if encyclopedia_bgm != null:
		return
	if encyclopedia_bgm_path.is_empty():
		return
	if ResourceLoader.exists(encyclopedia_bgm_path):
		encyclopedia_bgm = load(encyclopedia_bgm_path) as AudioStream


func _play_encyclopedia_bgm() -> void:
	_load_default_encyclopedia_bgm_if_needed()
	if encyclopedia_bgm == null:
		return
	if _active_encyclopedia_bgm == encyclopedia_bgm:
		return

	var audio_player := get_node_or_null("/root/AudioPlayer")
	if audio_player == null or not audio_player.has_method("play_bgm"):
		return

	if restore_previous_bgm and not _has_previous_bgm:
		if audio_player.has_method("get_current_bgm"):
			_previous_bgm = audio_player.call("get_current_bgm") as AudioStream
		else:
			_previous_bgm = null
		if audio_player.has_method("get_bgm_playback_position"):
			_previous_bgm_position = float(audio_player.call("get_bgm_playback_position"))
		else:
			_previous_bgm_position = 0.0
		_has_previous_bgm = true

	_ensure_stream_loop(encyclopedia_bgm)
	audio_player.call("play_bgm", encyclopedia_bgm, 0.0, false)
	_active_encyclopedia_bgm = encyclopedia_bgm


func _restore_previous_bgm_if_needed() -> void:
	if not _has_previous_bgm:
		_active_encyclopedia_bgm = null
		return

	var audio_player := get_node_or_null("/root/AudioPlayer")
	if audio_player != null:
		if _previous_bgm != null and audio_player.has_method("play_bgm"):
			audio_player.call("play_bgm", _previous_bgm, _previous_bgm_position, true)
		elif audio_player.has_method("stop_bgm"):
			audio_player.call("stop_bgm")

	_previous_bgm = null
	_previous_bgm_position = 0.0
	_has_previous_bgm = false
	_active_encyclopedia_bgm = null


func _ensure_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", true)
			return


func _save_pause_state() -> void:
	_was_tree_paused = get_tree().paused
	_has_saved_tree_pause = true

	_game_clock = get_node_or_null("/root/GameClock")
	if _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_was_clock_paused = bool(_game_clock.get("is_clock_paused"))
		_has_saved_clock_pause = true


func _pause_game() -> void:
	if pause_game_clock and _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_game_clock.call("set_clock_paused", true)

	if pause_scene_tree:
		get_tree().paused = true


func _restore_pause_state() -> void:
	if pause_game_clock and _has_saved_clock_pause and _game_clock != null and _game_clock.has_method("set_clock_paused"):
		_game_clock.call("set_clock_paused", _was_clock_paused)

	if pause_scene_tree and _has_saved_tree_pause:
		get_tree().paused = _was_tree_paused

	_has_saved_clock_pause = false
	_has_saved_tree_pause = false


func _apply_visual_theme() -> void:
	var main_panel := get_node_or_null("ScreenMargin/MainPanel") as PanelContainer
	if main_panel != null:
		main_panel.add_theme_stylebox_override("panel", _make_style(Color(0.035, 0.045, 0.060, 0.98), Color(0.0, 0.85, 0.95, 0.70), 2, 18, 18.0))

	for category_id in _get_category_ids():
		var list_panel := get_node_or_null(_make_category_node_path(category_id, "ListPanel")) as PanelContainer
		if list_panel != null:
			list_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.07, 0.09, 0.94), Color(0.38, 0.95, 0.84, 0.36), 1, 12, 12.0))

		var detail_panel := get_node_or_null(_make_category_node_path(category_id, "DetailPanel")) as PanelContainer
		if detail_panel != null:
			detail_panel.add_theme_stylebox_override("panel", _make_style(Color(0.075, 0.075, 0.095, 0.96), Color(1.0, 0.36, 0.95, 0.35), 1, 12, 12.0))

		var flavor_box := get_node_or_null(_make_category_node_path(category_id, "DetailPanel/DetailMargin/DetailScroll/DetailRows/FlavorBox")) as PanelContainer
		if flavor_box != null:
			flavor_box.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.055, 0.10, 0.86), Color(0.92, 0.42, 1.0, 0.30), 1, 10, 10.0))

	if _close_button != null:
		_close_button.add_theme_stylebox_override("normal", _make_style(Color(0.13, 0.10, 0.15, 0.95), Color(0.75, 0.35, 0.85, 0.75), 1, 10, 8.0))
		_close_button.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.12, 0.20, 0.98), Color(1.0, 0.55, 1.0, 0.92), 2, 10, 8.0))
		_close_button.add_theme_stylebox_override("pressed", _make_style(Color(0.08, 0.20, 0.23, 1.0), Color(0.25, 2.0, 2.0, 1.0), 2, 10, 8.0))


func _make_style(bg_color: Color, border_color: Color, border_width: int, corner_radius: int, margin: float = 3.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(margin)
	return style


func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	if node == null:
		return
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)
