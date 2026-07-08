extends Resource
class_name ItemTagData

@export var tag_id: StringName = &""
@export var display_name: String = ""
@export var category_id: StringName = &"general"
@export_multiline var description: String = ""


func is_valid() -> bool:
	return tag_id != &""


func get_tag_id_text() -> String:
	return String(tag_id)


func get_display_text() -> String:
	if not display_name.strip_edges().is_empty():
		return display_name.strip_edges()
	return get_tag_id_text()
