@tool
extends VBoxContainer

const PreviewModule := preload("res://addons/robin_item_creator/modules/ItemCreatorPreviewModule.gd")

const TITLE_TEXT := "Robin Item Creator"
const STATUS_TEXT := "入力フォームのみです。まだ保存処理はありません。"

var _display_name_edit: LineEdit
var _item_id_edit: LineEdit
var _category_option: OptionButton
var _description_edit: TextEdit
var _buy_price_spin: SpinBox
var _sell_price_spin: SpinBox
var _hunger_spin: SpinBox
var _water_spin: SpinBox
var _save_path_preview: LineEdit
var _summary_label: Label
var _last_auto_item_id := ""
var _is_updating_item_id := false


func _ready() -> void:
	_build_layout()
	_refresh_preview()


func _build_layout() -> void:
	if get_child_count() > 0:
		return
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0.0, 260.0)

	var header := _create_title_label(TITLE_TEXT)
	add_child(header)

	var status := Label.new()
	status.text = STATUS_TEXT
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	_add_section_title(form, "基本情報")
	_display_name_edit = LineEdit.new()
	_display_name_edit.placeholder_text = "例: フェリシティ・クラシックバーガー"
	_display_name_edit.text_changed.connect(_on_display_name_changed)
	_add_form_row(form, "表示名", _display_name_edit)

	_item_id_edit = LineEdit.new()
	_item_id_edit.placeholder_text = "例: food_0016_felicity_classic_burger"
	_item_id_edit.text_changed.connect(_on_item_id_changed)
	_add_form_row(form, "アイテムID", _item_id_edit)

	var id_button := Button.new()
	id_button.text = "表示名からID案を作る"
	id_button.tooltip_text = "英数字・半角スペース・ハイフン・アンダーバーだけを使ってID案を作ります。日本語名の場合は手入力推奨です。"
	id_button.pressed.connect(_on_generate_id_button_pressed)
	form.add_child(id_button)

	_category_option = OptionButton.new()
	_fill_category_options()
	_category_option.item_selected.connect(_on_category_selected)
	_add_form_row(form, "カテゴリ", _category_option)

	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0.0, 80.0)
	_description_edit.placeholder_text = "説明文。まだ保存されません。"
	_description_edit.text_changed.connect(_on_description_changed)
	_add_large_form_row(form, "説明", _description_edit)

	_add_section_title(form, "価格")
	_buy_price_spin = _create_int_spin_box(0, 999999, 1)
	_buy_price_spin.value_changed.connect(_on_numeric_value_changed)
	_add_form_row(form, "購入価格", _buy_price_spin)

	_sell_price_spin = _create_int_spin_box(0, 999999, 1)
	_sell_price_spin.value_changed.connect(_on_numeric_value_changed)
	_add_form_row(form, "売却価格", _sell_price_spin)

	_add_section_title(form, "効果プレビュー")
	_hunger_spin = _create_float_spin_box(0.0, 999.0, 1.0)
	_hunger_spin.value_changed.connect(_on_numeric_value_changed)
	_add_form_row(form, "満腹 +", _hunger_spin)

	_water_spin = _create_float_spin_box(0.0, 999.0, 1.0)
	_water_spin.value_changed.connect(_on_numeric_value_changed)
	_add_form_row(form, "水分 +", _water_spin)

	_add_section_title(form, "保存先プレビュー")
	_save_path_preview = LineEdit.new()
	_save_path_preview.editable = false
	_save_path_preview.placeholder_text = "保存先プレビュー"
	_add_form_row(form, "保存先", _save_path_preview)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_summary_label)

	var clear_button := Button.new()
	clear_button.text = "入力をクリア"
	clear_button.pressed.connect(_on_clear_button_pressed)
	form.add_child(clear_button)

	var save_placeholder := Button.new()
	save_placeholder.text = "保存はまだ未実装"
	save_placeholder.disabled = true
	form.add_child(save_placeholder)


func _create_title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(label)


func _add_form_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _add_large_form_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)

	var label := Label.new()
	label.text = label_text
	container.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(control)


func _create_int_spin_box(min_value: int, max_value: int, step: int) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = float(min_value)
	spin_box.max_value = float(max_value)
	spin_box.step = float(step)
	spin_box.value = float(min_value)
	spin_box.rounded = true
	return spin_box


func _create_float_spin_box(min_value: float, max_value: float, step: float) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = step
	spin_box.value = min_value
	return spin_box


func _fill_category_options() -> void:
	if _category_option == null:
		return
	_category_option.clear()
	var categories := PreviewModule.get_category_data()
	for index in range(categories.size()):
		var category := categories[index] as Dictionary
		_category_option.add_item(String(category.get("label", "カテゴリ")))
		_category_option.set_item_metadata(index, category.get("id", &"foods"))
	_category_option.selected = 0


func _on_display_name_changed(new_text: String) -> void:
	if _item_id_edit == null:
		_refresh_preview()
		return
	var current_item_id := _item_id_edit.text.strip_edges()
	if current_item_id.is_empty() or current_item_id == _last_auto_item_id:
		_set_item_id_text(String(PreviewModule.build_item_id(new_text, _get_selected_category_id())), true)
	_refresh_preview()


func _on_item_id_changed(_new_text: String) -> void:
	if _is_updating_item_id:
		return
	_last_auto_item_id = ""
	_refresh_preview()


func _on_category_selected(_index: int) -> void:
	if _item_id_edit != null:
		var current_item_id := _item_id_edit.text.strip_edges()
		if current_item_id.is_empty() or current_item_id == _last_auto_item_id:
			_set_item_id_text(String(PreviewModule.build_item_id(_display_name_edit.text, _get_selected_category_id())), true)
	_refresh_preview()


func _on_description_changed() -> void:
	_refresh_preview()


func _on_numeric_value_changed(_value: float) -> void:
	_refresh_preview()


func _on_generate_id_button_pressed() -> void:
	var display_name := ""
	if _display_name_edit != null:
		display_name = _display_name_edit.text
	_set_item_id_text(String(PreviewModule.build_item_id(display_name, _get_selected_category_id())), true)
	_refresh_preview()


func _on_clear_button_pressed() -> void:
	_last_auto_item_id = ""
	if _display_name_edit != null:
		_display_name_edit.text = ""
	if _item_id_edit != null:
		_set_item_id_text("", false)
	if _category_option != null:
		_category_option.selected = 0
	if _description_edit != null:
		_description_edit.text = ""
	if _buy_price_spin != null:
		_buy_price_spin.value = 0.0
	if _sell_price_spin != null:
		_sell_price_spin.value = 0.0
	if _hunger_spin != null:
		_hunger_spin.value = 0.0
	if _water_spin != null:
		_water_spin.value = 0.0
	_refresh_preview()


func _set_item_id_text(text: String, is_auto: bool) -> void:
	if _item_id_edit == null:
		return
	_is_updating_item_id = true
	_item_id_edit.text = text
	_is_updating_item_id = false
	_last_auto_item_id = text if is_auto else ""


func _refresh_preview() -> void:
	if _save_path_preview == null or _summary_label == null:
		return
	var display_name := _get_display_name_text()
	var item_id := _get_item_id()
	var category_id := _get_selected_category_id()
	var buy_price := _get_spin_int_value(_buy_price_spin)
	var sell_price := _get_spin_int_value(_sell_price_spin)
	var hunger_value := _get_spin_float_value(_hunger_spin)
	var water_value := _get_spin_float_value(_water_spin)
	_save_path_preview.text = PreviewModule.build_save_path(category_id, item_id)
	_summary_label.text = PreviewModule.get_preview_summary(display_name, item_id, category_id, buy_price, sell_price, hunger_value, water_value)


func _get_display_name_text() -> String:
	if _display_name_edit == null:
		return ""
	return _display_name_edit.text.strip_edges()


func _get_item_id() -> StringName:
	if _item_id_edit == null:
		return &""
	return StringName(_item_id_edit.text.strip_edges())


func _get_selected_category_id() -> StringName:
	if _category_option == null or _category_option.item_count <= 0:
		return &"foods"
	var selected_index := _category_option.selected
	if selected_index < 0:
		selected_index = 0
	var metadata: Variant = _category_option.get_item_metadata(selected_index)
	if metadata is StringName:
		return metadata as StringName
	return StringName(String(metadata))


func _get_spin_int_value(spin_box: SpinBox) -> int:
	if spin_box == null:
		return 0
	return maxi(int(roundf(float(spin_box.value))), 0)


func _get_spin_float_value(spin_box: SpinBox) -> float:
	if spin_box == null:
		return 0.0
	return maxf(float(spin_box.value), 0.0)
