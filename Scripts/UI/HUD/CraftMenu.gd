extends PanelContainer
class_name CraftMenu

signal crafting_method_selected(method_id: StringName)

const CATEGORY_COOKING: StringName = &"cooking"
const CATEGORY_DRINKS: StringName = &"drinks"
const CATEGORY_UNCATEGORIZED_DEBUG: StringName = &"uncategorized_debug"
const MIN_CRAFT_QUANTITY := 1
const MAX_CRAFT_QUANTITY := 99

const RECIPE_PATHS := [
	"res://Data/Craft/Recipes/Cooking_0001_WhiteRice.tres",
	"res://Data/Craft/Recipes/Drink_0001_WaterBottle.tres",
]

const LARGE_MENU_SIZE := Vector2(560.0, 560.0)
const RECIPE_CARD_SIZE := Vector2(520.0, 190.0)
const RECIPE_ICON_SIZE := Vector2(72.0, 72.0)

const TITLE_CRAFT_CODES := [0x5236, 0x4f5c]
const TITLE_COOKING_CODES := [0x6599, 0x7406]
const TITLE_DRINKS_CODES := [0x30c9, 0x30ea, 0x30f3, 0x30af]
const TITLE_UNCATEGORIZED_DEBUG_CODES := [0x672a, 0x5206, 0x985e, 0x20, 0x2f, 0x20, 0x30c7, 0x30d0, 0x30c3, 0x30b0]
const COOKING_BUTTON_TEXT_CODES := [0x6599, 0x7406]
const DRINKS_BUTTON_TEXT_CODES := [0x30c9, 0x30ea, 0x30f3, 0x30af]
const UNCATEGORIZED_DEBUG_BUTTON_TEXT_CODES := [0x672a, 0x5206, 0x985e, 0x0a, 0x30c7, 0x30d0, 0x30c3, 0x30b0]
const BACK_BUTTON_CODES := [0x623b, 0x308b]
const MAKE_BUTTON_CODES := [0x4f5c, 0x308b]
const CATEGORY_GUIDE_CODES := [0x5236, 0x4f5c, 0x3059, 0x308b, 0x7a2e, 0x985e, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002]
const COOKING_GUIDE_CODES := [0x4f5c, 0x308a, 0x305f, 0x3044, 0x6599, 0x7406, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002]
const DRINKS_GUIDE_CODES := [0x4f5c, 0x308a, 0x305f, 0x3044, 0x30c9, 0x30ea, 0x30f3, 0x30af, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002]
const UNCATEGORIZED_GUIDE_CODES := [0x30c7, 0x30d0, 0x30c3, 0x30b0, 0x7528, 0x306e, 0x672a, 0x5206, 0x985e, 0x30ab, 0x30c6, 0x30b4, 0x30ea, 0x3067, 0x3059, 0x3002]
const NO_RECIPE_CODES := [0x3053, 0x306e, 0x30ab, 0x30c6, 0x30b4, 0x30ea, 0x306b, 0x30ec, 0x30b7, 0x30d4, 0x304c, 0x3042, 0x308a, 0x307e, 0x305b, 0x3093, 0x3002]
const CRAFTED_SUFFIX_CODES := [0x3092, 0x4f5c, 0x308a, 0x307e, 0x3057, 0x305f, 0x3002]
const MISSING_MATERIAL_PREFIX_CODES := [0x6750, 0x6599, 0x304c, 0x8db3, 0x308a, 0x307e, 0x305b, 0x3093, 0x3a, 0x20]
const MISSING_FURNITURE_PREFIX_CODES := [0x5fc5, 0x8981, 0x5bb6, 0x5177, 0x304c, 0x3042, 0x308a, 0x307e, 0x305b, 0x3093, 0x3a, 0x20]
const INVENTORY_NOT_FOUND_CODES := [0x30a4, 0x30f3, 0x30d9, 0x30f3, 0x30c8, 0x30ea, 0x304c, 0x898b, 0x3064, 0x304b, 0x308a, 0x307e, 0x305b, 0x3093, 0x3002]
const OUTPUT_FAILED_CODES := [0x5b8c, 0x6210, 0x54c1, 0x3092, 0x8ffd, 0x52a0, 0x3067, 0x304d, 0x307e, 0x305b, 0x3093, 0x3067, 0x3057, 0x305f, 0x3002]
const KITCHEN_MODULE_NAME_CODES := [0x30ad, 0x30c3, 0x30c1, 0x30f3, 0x30e2, 0x30b8, 0x30e5, 0x30fc, 0x30eb]
const WHITE_RICE_NAME_CODES := [0x767d, 0x7c73]
const WATER_BOTTLE_NAME_CODES := [0x6c34, 0x5165, 0x308a, 0x30dc, 0x30c8, 0x30eb]
const REQUIRED_MATERIALS_LABEL_CODES := [0x5fc5, 0x8981, 0x6750, 0x6599, 0x3a, 0x20]
const REQUIRED_FURNITURE_LABEL_CODES := [0x5fc5, 0x8981, 0x5bb6, 0x5177, 0x3a, 0x20]
const QUANTITY_LABEL_CODES := [0x4f5c, 0x308b, 0x6570, 0x3a, 0x20]
const NONE_CODES := [0x306a, 0x3057]

@export var cooking_method_id: StringName = CATEGORY_COOKING
@export var actor_path: NodePath = NodePath("../../Robin")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var close_after_craft: bool = false

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var category_list: VBoxContainer = $MarginContainer/Rows/CategoryList
@onready var cooking_button: Button = $MarginContainer/Rows/CategoryList/CookingButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _selected_method_id: StringName = &""
var _current_category_id: StringName = &""
var _craft_quantity: int = 1
var _dynamic_nodes: Array[Node] = []
var _recipes: Array[CraftRecipeData] = []
var _back_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = LARGE_MENU_SIZE
	call_deferred("_apply_center_layout_after_parent")
	if not is_in_group(&"craft_menu"):
		add_to_group(&"craft_menu")
	_ensure_header_back_button()
	_move_detail_label_above_cards()
	close_button.pressed.connect(close_menu)
	cooking_button.pressed.connect(_on_cooking_pressed)
	_load_recipes_once()
	_show_category_view()


func _apply_center_layout_after_parent() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -LARGE_MENU_SIZE.x * 0.5
	offset_top = -LARGE_MENU_SIZE.y * 0.5
	offset_right = LARGE_MENU_SIZE.x * 0.5
	offset_bottom = LARGE_MENU_SIZE.y * 0.5


func _ensure_header_back_button() -> void:
	if _back_button != null and is_instance_valid(_back_button):
		return
	var header := close_button.get_parent() as HBoxContainer
	if header == null:
		return
	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(72.0, 28.0)
	_back_button.text = _string_from_codes(BACK_BUTTON_CODES)
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_pressed)
	header.add_child(_back_button)
	header.move_child(_back_button, close_button.get_index())


func _move_detail_label_above_cards() -> void:
	var rows := category_list.get_parent() as VBoxContainer
	if rows == null:
		return
	rows.move_child(detail_label, category_list.get_index())


func open_menu() -> void:
	visible = true
	_apply_center_layout_after_parent()
	if _current_category_id != &"":
		_show_recipe_view(_current_category_id)
		return
	_show_category_view()


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func get_selected_method_id() -> StringName:
	return _selected_method_id


func _on_cooking_pressed() -> void:
	_show_recipe_view(CATEGORY_COOKING)


func _show_category_view() -> void:
	_clear_dynamic_nodes()
	_current_category_id = &""
	_selected_method_id = &""
	title_label.text = _string_from_codes(TITLE_CRAFT_CODES)
	_set_header_back_visible(false)
	cooking_button.visible = false
	detail_label.text = _string_from_codes(CATEGORY_GUIDE_CODES)
	_add_category_button(CATEGORY_COOKING)


func _show_recipe_view(category_id: StringName) -> void:
	_clear_dynamic_nodes()
	_current_category_id = category_id
	_selected_method_id = category_id
	crafting_method_selected.emit(category_id)
	title_label.text = _get_category_title(category_id)
	_set_header_back_visible(true)
	cooking_button.visible = false
	detail_label.text = _get_category_guide(category_id)
	_add_category_tabs()
	_add_quantity_controls()
	var recipes := _get_recipes_for_category(category_id)
	if recipes.is_empty():
		detail_label.text = _string_from_codes(NO_RECIPE_CODES)
		return
	for recipe in recipes:
		_add_recipe_card(recipe)


func _set_header_back_visible(should_show: bool) -> void:
	_ensure_header_back_button()
	if _back_button == null:
		return
	_back_button.visible = should_show


func _add_category_button(category_id: StringName) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(520.0, 72.0)
	button.text = _get_category_button_text(category_id)
	button.pressed.connect(Callable(self, "_show_recipe_view").bind(category_id))
	category_list.add_child(button)
	_dynamic_nodes.append(button)


func _add_category_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	category_list.add_child(tabs)
	_dynamic_nodes.append(tabs)
	_add_tab_button(tabs, CATEGORY_COOKING)
	_add_tab_button(tabs, CATEGORY_DRINKS)
	_add_tab_button(tabs, CATEGORY_UNCATEGORIZED_DEBUG)


func _add_tab_button(parent_node: HBoxContainer, category_id: StringName) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(166.0, 40.0)
	button.toggle_mode = true
	button.button_pressed = _current_category_id == category_id
	button.text = _get_category_button_text(category_id).replace("\n", " ")
	button.pressed.connect(Callable(self, "_show_recipe_view").bind(category_id))
	parent_node.add_child(button)


func _add_quantity_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	category_list.add_child(row)
	_dynamic_nodes.append(row)

	var minus_button := Button.new()
	minus_button.custom_minimum_size = Vector2(48.0, 36.0)
	minus_button.text = "-"
	minus_button.pressed.connect(_on_quantity_minus_pressed)
	row.add_child(minus_button)

	var quantity_label := Label.new()
	quantity_label.custom_minimum_size = Vector2(408.0, 36.0)
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.text = "%s%d" % [_string_from_codes(QUANTITY_LABEL_CODES), _craft_quantity]
	row.add_child(quantity_label)

	var plus_button := Button.new()
	plus_button.custom_minimum_size = Vector2(48.0, 36.0)
	plus_button.text = "+"
	plus_button.pressed.connect(_on_quantity_plus_pressed)
	row.add_child(plus_button)


func _add_recipe_card(recipe: CraftRecipeData) -> void:
	if recipe == null:
		return
	var card := PanelContainer.new()
	card.custom_minimum_size = RECIPE_CARD_SIZE
	card.add_theme_stylebox_override("panel", _make_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 12)
	margin.add_child(card_row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = RECIPE_ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _load_recipe_icon(recipe)
	card_row.add_child(icon_rect)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	card_row.add_child(rows)

	var name_label := Label.new()
	name_label.text = _get_recipe_display_name(recipe)
	name_label.add_theme_font_size_override("font_size", 22)
	rows.add_child(name_label)

	var requirements_label := Label.new()
	requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirements_label.text = _build_requirement_text(recipe)
	rows.add_child(requirements_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(420.0, 42.0)
	button.text = "%s x%d" % [_string_from_codes(MAKE_BUTTON_CODES), _craft_quantity]
	button.pressed.connect(Callable(self, "_on_recipe_pressed").bind(recipe))
	rows.add_child(button)

	category_list.add_child(card)
	_dynamic_nodes.append(card)


func _on_back_pressed() -> void:
	_show_category_view()


func _on_quantity_minus_pressed() -> void:
	_set_craft_quantity(_craft_quantity - 1)


func _on_quantity_plus_pressed() -> void:
	_set_craft_quantity(_craft_quantity + 1)


func _set_craft_quantity(next_quantity: int) -> void:
	var clamped_quantity := clampi(next_quantity, MIN_CRAFT_QUANTITY, MAX_CRAFT_QUANTITY)
	if clamped_quantity == _craft_quantity:
		return
	_craft_quantity = clamped_quantity
	if _current_category_id != &"":
		_show_recipe_view(_current_category_id)


func _on_recipe_pressed(recipe: CraftRecipeData) -> void:
	var inventory := _get_inventory_module()
	if inventory == null:
		_show_and_push(_string_from_codes(INVENTORY_NOT_FOUND_CODES))
		return

	var missing_text := _get_missing_text(recipe, inventory)
	if not missing_text.is_empty():
		_show_and_push(missing_text)
		return

	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		inventory.remove_item(ingredient.item_data.category_id, ingredient.item_data.item_id, ingredient.amount * _craft_quantity)

	var added := false
	if recipe.output_item != null and inventory.has_method("add_food_item"):
		added = bool(inventory.call("add_food_item", recipe.output_item, recipe.output_amount * _craft_quantity))
	if not added:
		_refund_ingredients(recipe, inventory)
		_show_and_push(_string_from_codes(OUTPUT_FAILED_CODES))
		return

	var crafted_text := "%s x%d%s" % [_get_recipe_display_name(recipe), recipe.output_amount * _craft_quantity, _string_from_codes(CRAFTED_SUFFIX_CODES)]
	_show_and_push(crafted_text)
	if close_after_craft:
		close_menu()


func _load_recipes_once() -> void:
	if not _recipes.is_empty():
		return
	for path in RECIPE_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var recipe := load(path) as CraftRecipeData
		if recipe == null:
			continue
		_recipes.append(recipe)


func _get_recipes_for_category(category_id: StringName) -> Array[CraftRecipeData]:
	var result: Array[CraftRecipeData] = []
	for recipe in _recipes:
		if recipe == null:
			continue
		if recipe.category_id == category_id:
			result.append(recipe)
	return result


func _build_requirement_text(recipe: CraftRecipeData) -> String:
	return "%s%s\n%s%s" % [
		_string_from_codes(REQUIRED_MATERIALS_LABEL_CODES),
		_build_materials_text(recipe),
		_string_from_codes(REQUIRED_FURNITURE_LABEL_CODES),
		_build_furniture_text(recipe),
	]


func _build_materials_text(recipe: CraftRecipeData) -> String:
	if recipe == null or recipe.ingredients.is_empty():
		return _string_from_codes(NONE_CODES)
	var parts: Array[String] = []
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		parts.append("%s x%d" % [_get_item_display_name(ingredient.item_data), ingredient.amount * _craft_quantity])
	if parts.is_empty():
		return _string_from_codes(NONE_CODES)
	return " / ".join(parts)


func _build_furniture_text(recipe: CraftRecipeData) -> String:
	if recipe == null or recipe.required_furniture_ids.is_empty():
		return _string_from_codes(NONE_CODES)
	var parts: Array[String] = []
	for furniture_id_text in recipe.required_furniture_ids:
		parts.append(_get_furniture_display_name(StringName(furniture_id_text)))
	if parts.is_empty():
		return _string_from_codes(NONE_CODES)
	return " / ".join(parts)


func _get_missing_text(recipe: CraftRecipeData, inventory: Node) -> String:
	if recipe == null:
		return _string_from_codes(NO_RECIPE_CODES)
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		var needed_amount := ingredient.amount * _craft_quantity
		var current_amount := _get_inventory_item_amount(inventory, ingredient.item_data.category_id, ingredient.item_data.item_id)
		if current_amount < needed_amount:
			return "%s%s %d/%d" % [_string_from_codes(MISSING_MATERIAL_PREFIX_CODES), _get_item_display_name(ingredient.item_data), current_amount, needed_amount]
	for furniture_id_text in recipe.required_furniture_ids:
		var furniture_id := StringName(furniture_id_text)
		if not _has_furniture(furniture_id):
			return "%s%s" % [_string_from_codes(MISSING_FURNITURE_PREFIX_CODES), _get_furniture_display_name(furniture_id)]
	return ""


func _get_inventory_item_amount(inventory: Node, category_id: StringName, item_id: StringName) -> int:
	if inventory == null or not inventory.has_method("get_items"):
		return 0
	var entries: Array = inventory.call("get_items", category_id)
	var total := 0
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if entry.get("id", &"") == item_id:
			total += int(entry.get("amount", 0))
	return total


func _refund_ingredients(recipe: CraftRecipeData, inventory: Node) -> void:
	if recipe == null or inventory == null or not inventory.has_method("add_food_item"):
		return
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		inventory.call("add_food_item", ingredient.item_data, ingredient.amount * _craft_quantity)


func _has_furniture(furniture_id: StringName) -> bool:
	var placement_module := get_node_or_null(furniture_placement_module_path)
	if placement_module == null or not placement_module.has_method("get_furniture_root"):
		return false
	var furniture_root := placement_module.call("get_furniture_root") as Node
	if furniture_root == null:
		return false
	for child in furniture_root.get_children():
		var node := child as Node
		if _get_furniture_id(node) == furniture_id:
			return true
	return false


func _get_furniture_id(node: Node) -> StringName:
	if node == null:
		return &""
	if node.has_meta("furniture_id"):
		return node.get_meta("furniture_id", &"") as StringName
	for property_info in node.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == &"furniture_id":
			return node.get("furniture_id") as StringName
	return &""


func _get_category_title(category_id: StringName) -> String:
	match category_id:
		CATEGORY_COOKING:
			return _string_from_codes(TITLE_COOKING_CODES)
		CATEGORY_DRINKS:
			return _string_from_codes(TITLE_DRINKS_CODES)
		CATEGORY_UNCATEGORIZED_DEBUG:
			return _string_from_codes(TITLE_UNCATEGORIZED_DEBUG_CODES)
		_:
			return String(category_id)


func _get_category_button_text(category_id: StringName) -> String:
	match category_id:
		CATEGORY_COOKING:
			return _string_from_codes(COOKING_BUTTON_TEXT_CODES)
		CATEGORY_DRINKS:
			return _string_from_codes(DRINKS_BUTTON_TEXT_CODES)
		CATEGORY_UNCATEGORIZED_DEBUG:
			return _string_from_codes(UNCATEGORIZED_DEBUG_BUTTON_TEXT_CODES)
		_:
			return String(category_id)


func _get_category_guide(category_id: StringName) -> String:
	match category_id:
		CATEGORY_COOKING:
			return _string_from_codes(COOKING_GUIDE_CODES)
		CATEGORY_DRINKS:
			return _string_from_codes(DRINKS_GUIDE_CODES)
		CATEGORY_UNCATEGORIZED_DEBUG:
			return _string_from_codes(UNCATEGORIZED_GUIDE_CODES)
		_:
			return _string_from_codes(CATEGORY_GUIDE_CODES)


func _get_furniture_display_name(furniture_id: StringName) -> String:
	if furniture_id == &"kitchen_module":
		return _string_from_codes(KITCHEN_MODULE_NAME_CODES)
	return String(furniture_id)


func _get_item_display_name(item_data: FoodItemData) -> String:
	if item_data == null:
		return ""
	if not item_data.display_name.is_empty():
		return item_data.display_name
	return String(item_data.item_id)


func _get_recipe_display_name(recipe: CraftRecipeData) -> String:
	if recipe == null:
		return ""
	if recipe.recipe_id == &"cooking_0001_white_rice":
		return _string_from_codes(WHITE_RICE_NAME_CODES)
	if recipe.recipe_id == &"drink_0001_water_bottle":
		return _string_from_codes(WATER_BOTTLE_NAME_CODES)
	if recipe.output_item != null and not recipe.output_item.display_name.is_empty():
		return recipe.output_item.display_name
	return String(recipe.recipe_id)


func _load_recipe_icon(recipe: CraftRecipeData) -> Texture2D:
	if recipe == null or recipe.output_item == null:
		return null
	var icon_path := recipe.output_item.get_icon_path()
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _get_inventory_module() -> Node:
	var actor := get_node_or_null(actor_path)
	if actor == null:
		actor = get_tree().get_first_node_in_group(&"ai_character")
	if actor == null:
		return null
	if actor.has_method("get_inventory_module"):
		return actor.call("get_inventory_module") as Node
	return actor.get_node_or_null("RobinInventoryModule")


func _show_and_push(message: String) -> void:
	detail_label.text = message
	_push_message(message)


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log")
	if message_log == null:
		return
	if not message_log.has_method("add_message"):
		return
	message_log.call("add_message", message)


func _clear_dynamic_nodes() -> void:
	for node in _dynamic_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_dynamic_nodes.clear()


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.92)
	style.border_color = Color(0.14, 0.8, 0.95, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4.0)
	return style


func _string_from_codes(codes: Array) -> String:
	var value := ""
	for code in codes:
		value += String.chr(int(code))
	return value
