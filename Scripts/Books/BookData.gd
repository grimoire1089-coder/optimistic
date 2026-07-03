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
