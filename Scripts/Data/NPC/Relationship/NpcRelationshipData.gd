extends Resource
class_name NpcRelationshipData

@export var source_id: StringName = &""
@export var target_id: StringName = &""
@export var target_display_name: String = ""
@export_range(0, 100, 1) var friendship_value: int = 0
@export_range(0, 100, 1) var affection_value: int = 0
@export_multiline var note: String = ""


func get_target_label() -> String:
	if not target_display_name.is_empty():
		return target_display_name
	return String(target_id)


func get_summary_text() -> String:
	var target_label := get_target_label()
	if target_label.is_empty():
		return "友情 %d / 愛情 %d" % [friendship_value, affection_value]
	return "%s　友情 %d / 愛情 %d" % [target_label, friendship_value, affection_value]
