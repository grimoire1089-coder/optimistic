extends Control
class_name EncyclopediaOverlay

const DEFAULT_ENCYCLOPEDIA_BGM_PATH := "res://Assets/Audio/BGM/Picture book.ogg"
const DEFAULT_FOOD_ITEM_PATHS := [
	"res://Data/Items/Food/Food_0001_Nikuman.tres",
	"res://Data/Items/Food/Food_0016_FelicityClassicBurger.tres",
	"res://Data/Items/Food/Food_0013_WhiteRice.tres",
	"res://Data/Items/Food/Drink_1002_OolongTea.tres",
	"res://Data/Items/Food/Food_0008_WaterBottle.tres",
]

const FOOD_ROW_HEIGHT := 76.0
const FOOD_ICON_FRAME_SIZE := Vector2(72.0, 72.0)
const FOOD_ICON_SIZE := Vector2(64.0, 64.0)

@export var category_tabs_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs")
@export var close_button_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/Header/CloseButton")
@export var food_item_rows_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodListPanel/FoodListMargin/FoodListRows/FoodItemScroll/FoodItemRows")
@export var detail_icon_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/DetailScroll/FoodDetailRows/DetailIcon")
@export var detail_name_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/DetailScroll/FoodDetailRows/DetailNameLabel")
@export var detail_description_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/DetailScroll/FoodDetailRows/DetailDescriptionLabel")
@export var detail_meta_label_path: NodePath = NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/DetailScroll/FoodDetailRows/DetailMetaLabel")
@export var food_item_paths: PackedStringArray = PackedStringArray(DEFAULT_FOOD_ITEM_PATHS)
@export var encyclopedia_bgm: AudioStream
@export var encyclopedia_bgm_path: String = DEFAULT_ENCYCLOPEDIA_BGM_PATH
@export var restore_previous_bgm: bool = true
@export var pause_scene_tree: bool = true
@export var pause_game_clock: bool = true

var _category_tabs: TabContainer
var _close_button: Button
var _food_item_rows: VBoxContainer
var _detail_icon: TextureRect
var _detail_name_label: Label
var _detail_description_label: RichTextLabel
var _detail_meta_label: Label
var _game_clock: Node
var _food_entries: Array[Dictionary] = []
var _food_row_buttons: Array[Button] = []
var _selected_food_index: int = -1
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
	_resolve_refs()
	_load_default_encyclopedia_bgm_if_needed()
	_apply_visual_theme()
	_setup_tabs()
	_connect_close_button()
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
	_play_encyclopedia_bgm()
	_populate_food_entries()

	var selected_row := _get_selected_food_row()
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
	if _food_item_rows == null and not food_item_rows_path.is_empty():
		_food_item_rows = get_node_or_null(food_item_rows_path) as VBoxContainer
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


func _populate_food_entries() -> void:
	if _food_item_rows == null:
		return

	_food_entries.clear()
	_clear_food_rows()

	for item_path in food_item_paths:
		var entry := _make_food_entry(String(item_path))
		if entry.is_empty():
			continue
		_food_entries.append(entry)
		var row := _make_food_row(entry, _food_entries.size() - 1)
		_food_item_rows.add_child(row)
		_food_row_buttons.append(row)

	if _food_entries.size() > 0:
		_select_food_entry(0)
	else:
		_show_empty_detail()


func _clear_food_rows() -> void:
	_selected_food_index = -1
	_food_row_buttons.clear()
	if _food_item_rows == null:
		return
	for child in _food_item_rows.get_children():
		child.queue_free()


func _make_food_row(entry: Dictionary, index: int) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0.0, FOOD_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.text = ""
	row.tooltip_text = String(entry.get("description", ""))
	row.pressed.connect(Callable(self, "_on_food_row_pressed").bind(index))
	_apply_food_row_style(row, false)

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
	icon_frame.custom_minimum_size = FOOD_ICON_FRAME_SIZE
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
	icon.custom_minimum_size = FOOD_ICON_SIZE
	icon.texture = entry.get("icon") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(icon)

	var name_frame := PanelContainer.new()
	name_frame.custom_minimum_size = Vector2(0.0, FOOD_ICON_FRAME_SIZE.y)
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
	name_label.text = String(entry.get("display_name", "未登録食品"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	name_label.add_theme_font_size_override("font_size", 16)
	name_margin.add_child(name_label)

	return row


func _on_food_row_pressed(index: int) -> void:
	_select_food_entry(index)


func _select_food_entry(index: int) -> void:
	if index < 0 or index >= _food_entries.size():
		return
	_selected_food_index = index
	for row_index in range(_food_row_buttons.size()):
		_apply_food_row_style(_food_row_buttons[row_index], row_index == _selected_food_index)
	_show_food_entry(_food_entries[index])


func _get_selected_food_row() -> Button:
	if _selected_food_index < 0 or _selected_food_index >= _food_row_buttons.size():
		return null
	return _food_row_buttons[_selected_food_index]


func _apply_food_row_style(row: Button, is_selected: bool) -> void:
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

	var food_list_panel := get_node_or_null("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodListPanel") as PanelContainer
	if food_list_panel != null:
		food_list_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.07, 0.09, 0.94), Color(0.38, 0.95, 0.84, 0.36), 1, 12, 12.0))

	var food_detail_panel := get_node_or_null("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel") as PanelContainer
	if food_detail_panel != null:
		food_detail_panel.add_theme_stylebox_override("panel", _make_style(Color(0.075, 0.075, 0.095, 0.96), Color(1.0, 0.36, 0.95, 0.35), 1, 12, 12.0))

	var flavor_box := get_node_or_null("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage/FoodDetailPanel/FoodDetailMargin/DetailScroll/FoodDetailRows/FlavorBox") as PanelContainer
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
