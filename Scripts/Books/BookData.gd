extends Resource
class_name BookData

@export var book_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var author_name: String = ""
@export_multiline var body_text: String = ""
@export var icon: Texture2D
@export var category_id: StringName = &"books"
@export var genre_id: StringName = &"guide"
@export var genre_display_name: String = "ガイド"
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(1, 9999, 1) var page_count: int = 1
@export var skill_id: StringName = &""
@export_range(0, 999999, 1) var skill_experience_per_page: int = 0
@export var completion_bonus_skill_id: StringName = &""
@export_range(1, 100, 1) var completion_bonus_until_level: int = 1
@export_range(0.0, 10.0, 0.01) var completion_bonus_multiplier: float = 0.0


func get_item_id() -> StringName:
	return book_id


func get_genre_id() -> StringName:
	return genre_id


func get_genre_display_name() -> String:
	if genre_display_name.is_empty():
		return String(genre_id)
	return genre_display_name


func get_icon_path() -> String:
	if icon == null:
		return ""
	return icon.resource_path


func is_skill_book() -> bool:
	return skill_id != &"" and page_count > 0 and skill_experience_per_page > 0
