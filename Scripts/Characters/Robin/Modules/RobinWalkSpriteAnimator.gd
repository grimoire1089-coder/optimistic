extends Node
class_name RobinWalkSpriteAnimator

@export var sprite_path: NodePath = NodePath("../Sprite2D")
@export var frames_per_second: float = 6.0
@export var moving_bob_amount: float = 5.0
@export var moving_rotation_degrees: float = 2.0
@export var moving_scale_amount: float = 0.025

var _sprite: Sprite2D
var _last_direction: Vector2 = Vector2.DOWN
var _direction_cells: Dictionary = {}
var _base_position: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _base_rotation: float = 0.0
var _motion_time: float = 0.0


func setup() -> void:
	_setup_direction_cells()
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		push_warning("RobinWalkSpriteAnimator: Sprite2D が見つかりません。")
		return

	_sprite.hframes = 2
	_sprite.vframes = 4
	_base_position = _sprite.position
	_base_scale = _sprite.scale
	_base_rotation = _sprite.rotation
	_apply_direction_frame(Vector2.DOWN)
	_reset_motion_offsets()


func update_animation(move_velocity: Vector2, fallback_direction: Vector2, delta: float) -> void:
	if _sprite == null:
		return

	var is_moving := move_velocity.length_squared() > 1.0
	var direction := fallback_direction

	if is_moving:
		direction = move_velocity.normalized()
		_last_direction = direction
	elif direction.length_squared() > 0.001:
		direction = direction.normalized()
		_last_direction = direction
	else:
		direction = _last_direction

	_apply_direction_frame(direction)

	if not is_moving:
		_motion_time = 0.0
		_reset_motion_offsets()
		return

	_motion_time += delta * maxf(frames_per_second, 0.1)
	_apply_motion_offsets(direction)


func _setup_direction_cells() -> void:
	_direction_cells = {
		"down": Vector2i(0, 0),
		"up": Vector2i(1, 0),
		"right": Vector2i(0, 1),
		"left": Vector2i(1, 1),
		"down_right": Vector2i(0, 2),
		"down_left": Vector2i(1, 2),
		"up_right": Vector2i(0, 3),
		"up_left": Vector2i(1, 3),
	}


func _apply_direction_frame(direction: Vector2) -> void:
	var key := _direction_to_key(direction)
	var coords: Vector2i = _direction_cells.get(key, Vector2i(0, 0))
	_sprite.frame_coords = coords


func _apply_motion_offsets(direction: Vector2) -> void:
	var bob := sin(_motion_time * TAU) * moving_bob_amount
	var tilt_sign := 1.0
	if absf(direction.x) > 0.15:
		tilt_sign = sign(direction.x)

	var rotation_offset := sin(_motion_time * TAU) * deg_to_rad(moving_rotation_degrees) * tilt_sign
	var scale_offset := cos(_motion_time * TAU * 2.0) * moving_scale_amount

	_sprite.position = _base_position + Vector2(0.0, bob)
	_sprite.rotation = _base_rotation + rotation_offset
	_sprite.scale = Vector2(
		_base_scale.x * (1.0 - scale_offset),
		_base_scale.y * (1.0 + scale_offset)
	)


func _reset_motion_offsets() -> void:
	_sprite.position = _base_position
	_sprite.rotation = _base_rotation
	_sprite.scale = _base_scale


func _direction_to_key(direction: Vector2) -> String:
	if direction.length_squared() <= 0.001:
		return "down"

	var normalized_direction := direction.normalized()
	var x := 0
	var y := 0

	if normalized_direction.x > 0.35:
		x = 1
	elif normalized_direction.x < -0.35:
		x = -1

	if normalized_direction.y > 0.35:
		y = 1
	elif normalized_direction.y < -0.35:
		y = -1

	if x == 0 and y == 1:
		return "down"
	elif x == 0 and y == -1:
		return "up"
	elif x == 1 and y == 0:
		return "right"
	elif x == -1 and y == 0:
		return "left"
	elif x == 1 and y == 1:
		return "down_right"
	elif x == -1 and y == 1:
		return "down_left"
	elif x == 1 and y == -1:
		return "up_right"
	elif x == -1 and y == -1:
		return "up_left"

	if absf(normalized_direction.y) >= absf(normalized_direction.x):
		return "down" if normalized_direction.y >= 0.0 else "up"

	return "right" if normalized_direction.x >= 0.0 else "left"
