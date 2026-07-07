extends Node
class_name AICharacterDirectionalSpriteModule

@export var sprite_path: NodePath = NodePath("../Sprite2D")
@export var direction_source_path: NodePath = NodePath("../AICharacterRandomWanderModule")
@export var sprite_fit_module_path: NodePath = NodePath("../AICharacterSpriteFitModule")
@export_file("*.png") var front_texture_path: String = ""
@export_file("*.png") var back_texture_path: String = ""
@export_file("*.png") var left_texture_path: String = ""
@export_file("*.png") var right_texture_path: String = ""
@export var refresh_interval: float = 0.1

var _sprite: Sprite2D
var _direction_source: Node
var _sprite_fit_module: Node
var _refresh_timer: float = 0.0
var _last_direction_key: StringName = &""
var _texture_cache: Dictionary = {}


func _ready() -> void:
	_resolve_nodes()
	_refresh_texture(true)
	set_process(true)


func _process(delta: float) -> void:
	_refresh_timer -= maxf(delta, 0.0)
	if _refresh_timer > 0.0:
		return
	_refresh_timer = maxf(refresh_interval, 0.05)
	_refresh_texture(false)


func refresh_now() -> void:
	_refresh_texture(true)


func _refresh_texture(force: bool) -> void:
	_resolve_nodes()
	if _sprite == null:
		return
	var direction_key := _get_direction_key()
	if not force and direction_key == _last_direction_key:
		return
	_last_direction_key = direction_key
	var texture := _load_texture_for_direction(direction_key)
	if texture == null:
		return
	if _sprite.texture == texture:
		return
	_sprite.texture = texture
	_apply_sprite_fit()


func _resolve_nodes() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _direction_source == null or not is_instance_valid(_direction_source):
		_direction_source = get_node_or_null(direction_source_path)
		if _direction_source == null and get_parent() != null:
			_direction_source = get_parent().get_node_or_null("AICharacterRandomWanderModule")
	if _sprite_fit_module == null or not is_instance_valid(_sprite_fit_module):
		_sprite_fit_module = get_node_or_null(sprite_fit_module_path)


func _get_direction_key() -> StringName:
	var facing := Vector2.DOWN
	if _direction_source != null and _direction_source.has_method("get_facing_direction"):
		facing = _direction_source.call("get_facing_direction") as Vector2
	if absf(facing.x) >= absf(facing.y) and not is_zero_approx(facing.x):
		return &"right" if facing.x > 0.0 else &"left"
	if not is_zero_approx(facing.y):
		return &"front" if facing.y > 0.0 else &"back"
	return &"front"


func _load_texture_for_direction(direction_key: StringName) -> Texture2D:
	var texture_path := _get_texture_path(direction_key)
	if texture_path.is_empty():
		texture_path = front_texture_path
	if texture_path.is_empty():
		return null
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path] as Texture2D
	if not ResourceLoader.exists(texture_path):
		if texture_path != front_texture_path and not front_texture_path.is_empty():
			return _load_texture_for_direction(&"front")
		return null
	var texture := load(texture_path) as Texture2D
	_texture_cache[texture_path] = texture
	return texture


func _get_texture_path(direction_key: StringName) -> String:
	match direction_key:
		&"back":
			return back_texture_path if not back_texture_path.is_empty() else front_texture_path
		&"left":
			return left_texture_path if not left_texture_path.is_empty() else front_texture_path
		&"right":
			return right_texture_path if not right_texture_path.is_empty() else front_texture_path
		_:
			return front_texture_path


func _apply_sprite_fit() -> void:
	if _sprite_fit_module == null:
		return
	if _sprite_fit_module.has_method("apply_fit"):
		_sprite_fit_module.call("apply_fit")
