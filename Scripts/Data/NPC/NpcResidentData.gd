extends Resource
class_name NpcResidentData

@export var resident_id: StringName = &""
@export var display_name: String = "NPC"
@export_file("*.png") var portrait_path: String = ""
@export var location_text: String = ""
@export var mood_text: String = ""
@export_multiline var status_text: String = ""
@export var relationship_text: String = ""


func load_portrait() -> Texture2D:
	if portrait_path.is_empty():
		return null
	if not ResourceLoader.exists(portrait_path):
		return null
	return load(portrait_path) as Texture2D
