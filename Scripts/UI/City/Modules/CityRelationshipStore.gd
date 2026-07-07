extends RefCounted
class_name CityRelationshipStore


static func load_relationships(relationship_data_paths: Array[String]) -> Dictionary:
	var relationships_by_source: Dictionary = {}
	for data_path in relationship_data_paths:
		if data_path.is_empty():
			continue
		if not ResourceLoader.exists(data_path):
			push_warning("Relationship data not found: %s" % data_path)
			continue
		var relationship := load(data_path) as NpcRelationshipData
		if relationship == null:
			push_warning("Relationship data is invalid: %s" % data_path)
			continue
		var source_key := String(relationship.source_id)
		if source_key.is_empty():
			continue
		if not relationships_by_source.has(source_key):
			relationships_by_source[source_key] = []
		var source_relationships: Array = relationships_by_source[source_key]
		source_relationships.append(relationship)
		relationships_by_source[source_key] = source_relationships
	return relationships_by_source
