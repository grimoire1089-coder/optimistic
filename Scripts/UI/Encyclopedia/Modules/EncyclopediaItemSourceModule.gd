extends Node
class_name EncyclopediaItemSourceModule

const CATEGORY_FOODS := "foods"
const CATEGORY_TOOLS := "tools"
const CATEGORY_DRINKS := "drinks"
const CATEGORY_INGREDIENTS := "ingredients"
const VALID_CATEGORY_IDS := [CATEGORY_TOOLS, CATEGORY_FOODS, CATEGORY_DRINKS, CATEGORY_INGREDIENTS]
const SUPPORTED_EXTENSIONS := ["tres", "res"]

var _cached_item_paths_by_category: Dictionary = {}
var _has_scanned := false
var _scan_succeeded := false


func get_category_item_paths(category_id: String, fallback_paths: PackedStringArray, item_directories: PackedStringArray) -> PackedStringArray:
	_scan_if_needed(item_directories)
	if not _scan_succeeded:
		return fallback_paths

	var result := PackedStringArray()
	var paths: Array = _cached_item_paths_by_category.get(category_id, [])
	for raw_path in paths:
		result.append(String(raw_path))
	return result


func clear_cache() -> void:
	_cached_item_paths_by_category.clear()
	_has_scanned = false
	_scan_succeeded = false


func _scan_if_needed(item_directories: PackedStringArray) -> void:
	if _has_scanned:
		return

	_has_scanned = true
	_scan_succeeded = false
	_cached_item_paths_by_category.clear()
	for category_id in VALID_CATEGORY_IDS:
		_cached_item_paths_by_category[String(category_id)] = []

	for raw_directory in item_directories:
		var directory_path := String(raw_directory).strip_edges()
		if directory_path.is_empty():
			continue
		if _scan_directory(directory_path):
			_scan_succeeded = true

	for category_id in _cached_item_paths_by_category.keys():
		var paths: Array = _cached_item_paths_by_category[category_id]
		paths.sort()


func _scan_directory(directory_path: String) -> bool:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var child_path := directory_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory(child_path)
		else:
			_add_item_path_if_valid(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return true


func _add_item_path_if_valid(item_path: String) -> void:
	if item_path.get_extension().to_lower() not in SUPPORTED_EXTENSIONS:
		return
	if not ResourceLoader.exists(item_path):
		return

	var resource := ResourceLoader.load(item_path)
	if resource == null:
		return

	var item_id := _get_string_name_property(resource, "item_id")
	if item_id == &"":
		return

	var category_id := String(_get_string_name_property(resource, "category_id"))
	if not _is_valid_category_id(category_id):
		return

	var paths: Array = _cached_item_paths_by_category.get(category_id, [])
	if item_path not in paths:
		paths.append(item_path)
		_cached_item_paths_by_category[category_id] = paths


func _get_string_name_property(resource: Resource, property_name: String) -> StringName:
	var value: Variant = resource.get(property_name)
	if value == null:
		return &""
	if value is StringName:
		return value
	return StringName(String(value))


func _is_valid_category_id(category_id: String) -> bool:
	if category_id.is_empty():
		return false
	return category_id in VALID_CATEGORY_IDS
