extends PanelContainer
class_name CraftMenu

signal crafting_method_selected(method_id: StringName)

const RECIPE_PATHS := [
	"res://Data/Craft/Recipes/Cooking_0001_WhiteRice.tres",
]

const LARGE_MENU_TOP_RIGHT_OFFSET := Vector2(-444.0, 304.0)
const LARGE_MENU_SIZE := Vector2(420.0, 520.0)
const RECIPE_CARD_SIZE := Vector2(380.0, 170.0)

const TITLE_CRAFT_CODES := [0x5236, 0x4f5c]
const TITLE_COOKING_CODES := [0x6599, 0x7406]
const COOKING_BUTTON_TEXT_CODES := [0x6599, 0x7406, 0x0a, 0x5236, 0x4f5c, 0x65b9, 0x5f0f]
const BACK_BUTTON_CODES := [0x623b, 0x308b]
const MAKE_BUTTON_CODES := [0x4f5c, 0x308b]
const GUIDE_TEXT_CODES := [0x5236, 0x4f5c, 0x65b9, 0x5f0f, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002]
const COOKING_GUIDE_CODES := [0x4f5c, 0x308a, 0x305f, 0x3044, 0x6599, 0x7406, 0x3092, 0x9078, 0x3093, 0x3067, 0x304f, 0x3060, 0x3055, 0x3044, 0x3002]
const NO_RECIPE_CODES := [0x6599, 0x7406, 0x30ec, 0x30b7, 0x30d4, 0x304c, 0x3042, 0x308a, 0x307e, 0x305b, 0x3093, 0x3002]
const CRAFTED_SUFFIX_CODES := [0x3092, 0x4f5c, 0x308a, 0x307e, 0x3057, 0x305f, 0x3002]
const MISSING_MATERIAL_PREFIX_CODES := [0x6750, 0x6599, 0x304c, 0x8db3, 0x308a, 0x307e, 0x305b, 0x3093, 0x3a, 0x20]
const MISSING_FURNITURE_PREFIX_CODES := [0x5fc5, 0x8981, 0x5bb6, 0x5177, 0x304c, 0x3042, 0x308a, 0x307e, 0x305b, 0x3093, 0x3a, 0x20]
const INVENTORY_NOT_FOUND_CODES := [0x30a4, 0x30f3, 0x30d9, 0x30f3, 0x30c8, 0x30ea, 0x304c, 0x898b, 0x3064, 0x304b, 0x308a, 0x307e, 0x305b, 0x3093, 0x3002]
const OUTPUT_FAILED_CODES := [0x5b8c, 0x6210, 0x54c1, 0x3092, 0x8ffd, 0x52a0, 0x3067, 0x304d, 0x307e, 0x305b, 0x3093, 0x3067, 0x3057, 0x305f, 0x3002]
const KITCHEN_MODULE_NAME_CODES := [0x30ad, 0x30c3, 0x30c1, 0x30f3, 0x30e2, 0x30b8, 0x30e5, 0x30fc, 0x30eb]
const WHITE_RICE_NAME_CODES := [0x767d, 0x7c73]
const REQUIRED_MATERIALS_LABEL_CODES := [0x5fc5, 0x8981, 0x6750, 0x6599, 0x3a, 0x20]
const REQUIRED_FURNITURE_LABEL_CODES := [0x5fc5, 0x8981, 0x5bb6, 0x5177, 0x3a, 0x20]
const NONE_CODES := [0x306a, 0x3057]

@export var cooking_method_id: StringName = &"cooking"
@export var actor_path: NodePath = NodePath("../../Robin")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var close_after_craft: bool = false

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var category_list: VBoxContainer = $MarginContainer/Rows/CategoryList
@onready var cooking_button: Button = $MarginContainer/Rows/CategoryList/CookingButton
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel

var _selected_method_id: StringName = &""
var _dynamic_nodes: Array[Node] = []
var _recipes: Array[CraftRecipeData] = []


func _ready() -> void:
	visible = false
	custom_minimum_size = LARGE_MENU_SIZE
	call_deferred("_apply_large_layout_after_parent")
	if not is_in_group(&"craft_menu"):
		add_to_group(&"craft_menu")
	close_button.pressed.connect(close_menu)
	cooking_button.pressed.connect(_on_cooking_pressed)
	_load_recipes_once()
	_show_category_view()


func _apply_large_layout_after_parent() -> void:
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = LARGE_MENU_TOP_RIGHT_OFFSET.x
	offset_top = LARGE_MENU_TOP_RIGHT_OFFSET.y
	offset_right = LARGE_MENU_TOP_RIGHT_OFFSET.x + LARGE_MENU_SIZE.x
	offset_bottom = LARGE_MENU_TOP_RIGHT_OFFSET.y + LARGE_MENU_SIZE.y


func open_menu() -> void:
	visible = true
	_apply_large_layout_after_parent()
	if _selected_method_id == cooking_method_id:
		_show_cooking_view()
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
	_selected_method_id = cooking_method_id
	crafting_method_selected.emit(cooking_method_id)
	_show_cooking_view()


func _show_category_view() -> void:
	_clear_dynamic_nodes()
	title_label.text = _string_from_codes(TITLE_CRAFT_CODES)
	cooking_button.visible = true
	cooking_button.custom_minimum_size = Vector2(380.0, 72.0)
	cooking_button.text = _string_from_codes(COOKING_BUTTON_TEXT_CODES)
	detail_label.text = _string_from_codes(GUIDE_TEXT_CODES)


func _show_cooking_view() -> void:
	_clear_dynamic_nodes()
	title_label.text = _string_from_codes(TITLE_COOKING_CODES)
	cooking_button.visible = false
	_add_back_button()
	if _recipes.is_empty():
		detail_label.text = _string_from_codes(NO_RECIPE_CODES)
		return
	for recipe in _recipes:
		_add_recipe_card(recipe)
	detail_label.text = _string_from_codes(COOKING_GUIDE_CODES)


func _add_back_button() -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(380.0, 40.0)
	button.text = _string_from_codes(BACK_BUTTON_CODES)
	button.pressed.connect(_on_back_pressed)
	category_list.add_child(button)
	_dynamic_nodes.append(button)


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

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var name_label := Label.new()
	name_label.text = _get_recipe_display_name(recipe)
	name_label.add_theme_font_size_override("font_size", 22)
	rows.add_child(name_label)

	var requirements_label := Label.new()
	requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirements_label.text = _build_requirement_text(recipe)
	rows.add_child(requirements_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(356.0, 42.0)
	button.text = _string_from_codes(MAKE_BUTTON_CODES)
	button.pressed.connect(Callable(self, "_on_recipe_pressed").bind(recipe))
	rows.add_child(button)

	category_list.add_child(card)
	_dynamic_nodes.append(card)


func _on_back_pressed() -> void:
	_selected_method_id = &""
	_show_category_view()


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
		inventory.remove_item(ingredient.item_data.category_id, ingredient.item_data.item_id, ingredient.amount)

	var added := false
	if recipe.output_item != null and inventory.has_method("add_food_item"):
		added = bool(inventory.call("add_food_item", recipe.output_item, recipe.output_amount))
	if not added:
		_refund_ingredients(recipe, inventory)
		_show_and_push(_string_from_codes(OUTPUT_FAILED_CODES))
		return

	var crafted_text := "%s%s" % [_get_recipe_display_name(recipe), _string_from_codes(CRAFTED_SUFFIX_CODES)]
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
		if recipe.category_id != cooking_method_id:
			continue
		_recipes.append(recipe)


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
		parts.append("%s x%d" % [_get_item_display_name(ingredient.item_data), ingredient.amount])
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
		var current_amount := _get_inventory_item_amount(inventory, ingredient.item_data.category_id, ingredient.item_data.item_id)
		if current_amount < ingredient.amount:
			return "%s%s %d/%d" % [_string_from_codes(MISSING_MATERIAL_PREFIX_CODES), _get_item_display_name(ingredient.item_data), current_amount, ingredient.amount]
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
		inventory.call("add_food_item", ingredient.item_data, ingredient.amount)


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
	if recipe.output_item != null and not recipe.output_item.display_name.is_empty():
		return recipe.output_item.display_name
	return String(recipe.recipe_id)


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
