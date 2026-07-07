extends Node
class_name AICharacterSpriteFitModule

@export var sprite_path: NodePath = NodePath("../Sprite2D")
@export var target_display_size: Vector2 = Vector2(96.0, 192.0)
@export var preserve_aspect: bool = true

var _sprite: Sprite2D


func _ready() -> void:
	_apply_fit()


func apply_fit() -> void:
	_apply_fit()


func _apply_fit() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		return
	if _sprite.texture == null:
		return
	var texture_size := _sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	if target_display_size.x <= 0.0 or target_display_size.y <= 0.0:
		return

	var scale_x := target_display_size.x / texture_size.x
	var scale_y := target_display_size.y / texture_size.y
	if preserve_aspect:
		var uniform_scale := minf(scale_x, scale_y)
		_sprite.scale = Vector2(uniform_scale, uniform_scale)
		return
	_sprite.scale = Vector2(scale_x, scale_y)
