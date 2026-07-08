extends Resource
class_name ItemTagDatabase

@export var tags: Array[ItemTagData] = []


func find_by_id(tag_id: StringName) -> ItemTagData:
	if tag_id == &"":
		return null
	for tag in tags:
		if tag == null:
			continue
		if tag.tag_id == tag_id:
			return tag
	return null


func has_tag(tag_id: StringName) -> bool:
	return find_by_id(tag_id) != null


func get_tag_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for tag in tags:
		if tag == null or tag.tag_id == &"":
			continue
		result.append(String(tag.tag_id))
	return result


func get_tags_by_category(category_id: StringName) -> Array[ItemTagData]:
	var result: Array[ItemTagData] = []
	for tag in tags:
		if tag == null:
			continue
		if tag.category_id == category_id:
			result.append(tag)
	return result
