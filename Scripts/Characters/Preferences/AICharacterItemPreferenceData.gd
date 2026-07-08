extends Resource
class_name AICharacterItemPreferenceData

@export var preference_id: StringName = &""
@export var display_name: String = ""
@export var favorite_item_ids: PackedStringArray = PackedStringArray()
@export var liked_item_ids: PackedStringArray = PackedStringArray()
@export var disliked_item_ids: PackedStringArray = PackedStringArray()
@export var favorite_tag_ids: PackedStringArray = PackedStringArray()
@export var liked_tag_ids: PackedStringArray = PackedStringArray()
@export var disliked_tag_ids: PackedStringArray = PackedStringArray()
@export var favorite_item_score: int = 100
@export var liked_item_score: int = 30
@export var favorite_tag_score: int = 25
@export var liked_tag_score: int = 10
@export var disliked_tag_score: int = -25
@export var disliked_item_score: int = -100


func get_item_preference_score(item_id: StringName, tag_ids: PackedStringArray = PackedStringArray()) -> int:
	var score := 0
	var item_id_text := String(item_id)
	if _has_id(favorite_item_ids, item_id_text):
		score += favorite_item_score
	if _has_id(liked_item_ids, item_id_text):
		score += liked_item_score
	if _has_id(disliked_item_ids, item_id_text):
		score += disliked_item_score

	for tag_id in tag_ids:
		var tag_id_text := String(tag_id)
		if _has_id(favorite_tag_ids, tag_id_text):
			score += favorite_tag_score
		if _has_id(liked_tag_ids, tag_id_text):
			score += liked_tag_score
		if _has_id(disliked_tag_ids, tag_id_text):
			score += disliked_tag_score
	return score


func _has_id(ids: PackedStringArray, target_id: String) -> bool:
	if target_id.is_empty():
		return false
	for raw_id in ids:
		if String(raw_id) == target_id:
			return true
	return false
