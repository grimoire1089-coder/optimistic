extends Resource
class_name CraftRecipeData

@export var recipe_id: StringName = &""
@export var category_id: StringName = &"cooking"
@export var output_item: FoodItemData
@export var output_amount: int = 1
@export var ingredients: Array[CraftIngredientData] = []
@export var required_furniture_ids: PackedStringArray = PackedStringArray()
