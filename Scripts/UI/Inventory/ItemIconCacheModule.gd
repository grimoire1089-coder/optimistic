extends Node
class_name ItemIconCacheModule

@export var max_cached_icons: int = 64:
	set(value):
		max_cached_icons = maxi(value, 1)
		_trim_cache()

var _textures_by_path: Dictionary = {}
var _access_order: Array[String] = []


func get_texture(icon_path: String) -> Texture2D:
	var safe_path := icon_path.strip_edges()
	if safe_path.is_empty():
		return null

	if _textures_by_path.has(safe_path):
		_touch(safe_path)
		return _textures_by_path[safe_path] as Texture2D

	if not ResourceLoader.exists(safe_path):
		return null

	var resource := ResourceLoader.load(safe_path)
	if not (resource is Texture2D):
		return null

	var texture := resource as Texture2D
	_textures_by_path[safe_path] = texture
	_touch(safe_path)
	_trim_cache()
	return texture


func set_max_cached_icons(value: int) -> void:
	max_cached_icons = value
	_trim_cache()


func clear_cache() -> void:
	_textures_by_path.clear()
	_access_order.clear()


func get_cached_count() -> int:
	return _textures_by_path.size()


func has_cached(icon_path: String) -> bool:
	return _textures_by_path.has(icon_path.strip_edges())


func _touch(icon_path: String) -> void:
	_access_order.erase(icon_path)
	_access_order.append(icon_path)


func _trim_cache() -> void:
	var safe_limit := maxi(max_cached_icons, 1)
	while _access_order.size() > safe_limit:
		var removed_path := _access_order[0]
		_access_order.remove_at(0)
		_textures_by_path.erase(removed_path)
