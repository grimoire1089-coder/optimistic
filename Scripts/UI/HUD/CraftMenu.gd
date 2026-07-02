extends PanelContainer
class_name CraftMenu

signal crafting_method_selected(method_id: StringName)

const RECIPE_PATHS := [
	"res://Data/Craft/Recipes/Cooking_0001_WhiteRice.tres",
]

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
var _dynamic_buttons: Array[Button] = []
var _recipes: Array[CraftRecipeData] = []


func _ready() -> void:
	visible = false
	if not is_in_group(&"craft_menu"):
		add_to_group(&"craft_menu")
	close_button.pressed.connect(close_menu)
	cooking_button.pressed.connect(_on_cooking_pressed)
	_load_recipes_once()
	_show_category_view()


func open_menu() -> void:
	visible = true
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
	_clear_dynamic_buttons()
	title_label.text = _string_from_codes(TITLE_CRAFT_CODES)
	cooking_button.visible = true
	cooking_button.text = _string_from_codes(COOKING_BUTTON_TEXT_CODES)
	detail_label.text = _string_from_codes(GUIDE_TEXT_CODES)


func _show_cooking_view() -> void:
	_clear_dynamic_buttons()
	title_label.text = _string_from_codes(TITLE_COOKING_CODES)
	cooking_button.visible = false
	_add_back_button()
	if _recipes.is_empty():
		detail_label.text = _string_from_codes(NO_RECIPE_CODES)
		return
	for recipe in _recipes:
		_add_recipe_button(recipe)
	detail_label.text = _string_from_codes(COOKING_GUIDE_CODES)


func _add_back_button() -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(280.0, 32.0)
	button.text = _string_from_codes(BACK_BUTTON_CODES)
	button.pressed.connect(_on_back_pressed)
	category_list.add_child(button)
	_dynamic_buttons.append(button)


func _add_recipe_button(recipe: CraftRecipeData) -> void:
	if recipe == null:
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(280.0, 56.0)
	button.text = "%s\n%s" % [_get_recipe_display_name(recipe), _string_from_codes(MAKE_BUTTON_CODES)]
	button.pressed.connect(Callable(self, "_on_recipe_pressed").bind(recipe))
	category_list.add_child(button)
	_dynamic_buttons.append(button)


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


func _get_missing_text(recipe: CraftRecipeData, inventory: Node) -> String:
	if recipe == null:
		return _string_from_codes(NO_RECIPE_CODES)
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.item_data == null:
			continue
		var current_amount := _get_inventory_item_amount(inventory, ingredient.item_data.category_id, ingredient.item_data.item_id)
		if current_amount < ingredient.amount:
			return "%s%s %d/%d" % [_string_from_codes(MISSING_MATERIAL_PREFIX_CODES), ingredient.item_data.display_name, current_amount, ingredient.amount]
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


func _get_recipe_display_name(recipe: CraftRecipeData) -> String:
	if recipe == null or recipe.output_item == null:
		return ""
	return recipe.output_item.display_name


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


func _clear_dynamic_buttons() -> void:
	for button in _dynamic_buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_dynamic_buttons.clear()


func _string_from_codes(codes: Array) -> String:
	var value := ""
	for code in codes:
		value += String.chr(int(code))
	return value
