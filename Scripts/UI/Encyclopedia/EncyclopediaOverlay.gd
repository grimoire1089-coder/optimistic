extends Control
class_name EncyclopediaOverlay

const DEFAULT_FOOD_ITEM_PATHS := [
	"res://Data/Items/Food/Food_0001_Nikuman.tres",
	"res://Data/Items/Food/Food_0016_FelicityClassicBurger.tres",
	"res://Data/Items/Food/Food_0013_WhiteRice.tres",
	"res://Data/Items/Food/Drink_1002_OolongTea.tres",
	"res://Data/Items/Food/Food_0008_WaterBottle.tres",
]

@export var category_tabs_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs")
@export var close_button_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/Header/CloseButton")
@export var food_item_list_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodListPanel/FoodListMargin/FoodListRows/FoodItemList")
@export var detail_icon_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/FoodDetailRows/DetailIcon")
@export var detail_name_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/FoodDetailRows/DetailNameLabel")
@export var detail_description_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/FoodDetailRows/DetailDescriptionLabel")
@export var detail_meta_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/FoodDetailRows/DetailMetaLabel")
@export var food_item_paths: PackedStringArray = PackedStringArray(DEFAULT_FOOD_ITEM_PATHS)
@export var pause_scene_tree: bool = true
@export var pause_game_clock: bool = true

var _category_tabs: TabContainer
var _close_button: Button
var _food_item_list: ItemList
var _detail_icon: TextureRect
var _detail_name_label: Label
var _detail_description_label: RichTextLabel
var _detail_meta_label: Label
var _game_clock: Node
var _food_entries: Array[Dictionary] = []
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
	_resolve_refs()
	_apply_visual_theme()
	_setup_tabs()
	_connect_close_button()
	_connect_food_list()
	_populate_food_entries()
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
	_save_pause_state()
	visible = true
	move_to_front()
	_pause_game()
	_populate_food_entries()

	if _food_item_list != null and _food_item_list.item_count > 0:
		_food_item_list.grab_focus()


func close_encyclopedia() -> void:
	if not visible:
		return

	visible = false
	_restore_pause_state()


func toggle_encyclopedia() -> void:
	if visible:
		close_encyclopedia()
	else:
		open_encyclopedia()


func _exit_tree() -> void:
	if visible:
		_restore_pause_state()


func _resolve_refs() -> void:
	if _category_tabs == null and not category_tabs_path.is_empty():
		_category_tabs = get_node_or_null(category_tabs_path) as TabContainer
	if _close_button == null and not close_button_path.is_empty():
		_close_button = get_node_or_null(close_button_path) as Button
	if _food_item_list == null and not food_item_list_path.is_empty():
		_food_item_list = get_node_or_null(food_item_list_path) as ItemList
	if _detail_icon == null and not detail_icon_path.is_empty():
		_detail_icon = get_node_or_null(detail_icon_path) as TextureRect
	if _detail_name_label == null and not detail_name_label_path.is_empty():
		_detail_name_label = get_node_or_null(detail_name_label_path) as Label
	if _detail_description_label == null and not detail_description_label_path.is_empty():
		_detail_description_label = get_node_or_null(detail_description_label_path) as RichTextLabel
	if _detail_meta_label == null and not detail_meta_label_path.is_empty():
		_detail_meta_label = get_node_or_null(detail_meta_label_path) as Label


func _setup_tabs() -> void:
	if _category_tabs == null:
		return
	if _category_tabs.get_tab_count() >= 1:
		_category_tabs.set_tab_title(0, "食品")


func _connect_close_button() -> void:
	if _close_button == null:
		return
	if not _close_button.pressed.is_connected(close_encyclopedia):
		_close_button.pressed.connect(close_encyclopedia)


func _connect_food_list() -> void:
	if _food_item_list == null:
		return
	if not _food_item_list.item_selected.is_connected(_on_food_item_selected):
		_food_item_list.item_selected.connect(_on_food_item_selected)


func _populate_food_entries() -> void:
	if _food_item_list == null:
		return

	_food_entries.clear()
	_food_item_list.clear()

	for item_path in food_item_paths:
		var entry := _make_food_entry(String(item_path))
		if entry.is_empty():
			continue
		var icon := entry.get("icon") as Texture2D
		var index := _food_item_list.add_item(String(entry.get("display_name", "未登録食品")), icon, true)
		_food_item_list.set_item_tooltip(index, String(entry.get("description", "")))
		_food_item_list.set_item_metadata(index, entry)
		_food_entries.append(entry)

	if _food_item_list.item_count > 0:
		_food_item_list.select(0)
		_show_food_entry(_food_entries[0])
	else:
		_show_empty_detail()


func _make_food_entry(item_path: String) -> Dictionary:
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		return {}
	var resource := load(item_path)
	if resource == null:
		return {}

	var display_name := String(resource.get("display_name"))
	if display_name.is_empty():
		display_name = item_path.get_file().get_basename()

	return {
		"path": item_path,
		"display_name": display_name,
		"description": String(resource.get("description")),
		"icon": resource.get("icon") as Texture2D,
		"category_id": String(resource.get("category_id")),
		"buy_price": int(resource.get("buy_price")),
		"sell_price": int(resource.get("sell_price")),
	}


func _on_food_item_selected(index: int) -> void:
	if index < 0 or index >= _food_entries.size():
		return
	_show_food_entry(_food_entries[index])


func _show_food_entry(entry: Dictionary) -> void:
	if _detail_icon != null:
		_detail_icon.texture = entry.get("icon") as Texture2D
	if _detail_name_label != null:
		_detail_name_label.text = String(entry.get("display_name", "未登録食品"))
	if _detail_description_label != null:
		_detail_description_label.text = String(entry.get("description", "まだ説明が登録されていません。"))
	if _detail_meta_label != null:
		_detail_meta_label.text = _make_meta_text(entry)


func _show_empty_detail() -> void:
	if _detail_icon != null:
		_detail_icon.texture = null
	if _detail_name_label != null:
		_detail_name_label.text = "食品テンプレート"
	if _detail_description_label != null:
		_detail_description_label.text = "食品タブ用の図鑑テンプレートです。ここに食品・料理・飲料の世界観説明を追加していきます。"
	if _detail_meta_label != null:
		_detail_meta_label.text = "カテゴリ：食品 / 登録数：0"


func _make_meta_text(entry: Dictionary) -> String:
	var category_name := _get_category_display_name(String(entry.get("category_id", "foods")))
	var buy_price := int(entry.get("buy_price", 0))
	var sell_price := int(entry.get("sell_price", 0))
	return "カテゴリ：%s / 購入：%d CR / 売却：%d CR" % [category_name, buy_price, sell_price]


func _get_category_display_name(category_id: String) -> String:
	match category_id:
		"foods":
			return "食品"
		"drinks":
			return "飲料"
		"ingredients":
			return "食材"
		"recipes":
			return "レシピ"
		_:
			return category_id


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

	var food_list_panel := get_node_or_null("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodListPanel") as PanelContainer
	if food_list_panel != null:
		food_list_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.07, 0.09, 0.94), Color(0.38, 0.95, 0.84, 0.36), 1, 12, 12.0))

	var food_detail_panel := get_node_or_null("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel") as PanelContainer
	if food_detail_panel != null:
		food_detail_panel.add_theme_stylebox_override("panel", _make_style(Color(0.075, 0.075, 0.095, 0.96), Color(1.0, 0.36, 0.95, 0.35), 1, 12, 12.0))

	if _close_button != null:
		_close_button.add_theme_stylebox_override("normal", _make_style(Color(0.13, 0.10, 0.15, 0.95), Color(0.75, 0.35, 0.85, 0.75), 1, 10, 8.0))
		_close_button.add_theme_stylebox_override("hover", _make_style(Color(0.18, 0.12, 0.20, 0.98), Color(1.0, 0.55, 1.0, 0.92), 2, 10, 8.0))
		_close_button.add_theme_stylebox_override("pressed", _make_style(Color(0.08, 0.20, 0.23, 1.0), Color(0.25, 2.0, 2.0, 1.0), 2, 10, 8.0))

	if _food_item_list != null:
		_food_item_list.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
		_food_item_list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0, 1.0))


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
