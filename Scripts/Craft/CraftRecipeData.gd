extends Resource
class_name CraftRecipeData

@export var recipe_id: StringName = &""
@export var category_id: StringName = &"cooking"
@export_range(1, 9999, 1) var craft_game_minutes: int = 1
@export var output_item: FoodItemData
@export var output_amount: int = 1
@export var ingredients: Array[CraftIngredientData] = []
@export var required_furniture_ids: PackedStringArray = PackedStringArray()
