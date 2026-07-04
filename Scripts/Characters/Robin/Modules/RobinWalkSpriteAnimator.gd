extends Node
class_name RobinWalkSpriteAnimator

@export var sprite_path: NodePath = NodePath("../Sprite2D")
@export var frames_per_second: float = 6.0
@export var moving_bob_amount: float = 5.0
@export var moving_rotation_degrees: float = 2.0
@export var moving_scale_amount: float = 0.025
@export var detect_position_delta_movement: bool = true
@export var fit_to_room_grid: bool = true
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var fit_grid_cells: Vector2 = Vector2(2.0, 4.0)
@export var fit_padding_pixels: Vector2 = Vector2.ZERO
@export var fit_alpha_threshold: float = 0.03
@export var fit_fallback_visible_frame_size: Vector2 = Vector2(202.0, 420.0)
@export var fit_measure_texture_alpha_bounds: bool = false

var _sprite: Sprite2D
var _actor: Node2D
var _room_map: RoomMapGridModule
var _last_direction: Vector2 = Vector2.DOWN
var _direction_cells: Dictionary = {}
var _base_position: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _base_rotation: float = 0.0
var _motion_time: float = 0.0
var _last_actor_position: Vector2 = Vector2.ZERO
var _has_last_actor_position := false
var _fit_source_visible_frame_size := Vector2.ZERO
var _last_fit_cell_size := Vector2(-1.0, -1.0)


func setup() -> void:
	_setup_direction_cells()
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_actor = get_parent() as Node2D
	if _actor != null:
		_last_actor_position = _actor.global_position
		_has_last_actor_position = true
	if _sprite == null:
		push_warning("RobinWalkSpriteAnimator: Sprite2D が見つかりません。")
		return

	_sprite.hframes = 2
	_sprite.vframes = 4
	_base_position = _sprite.position
	_base_scale = _sprite.scale
	_base_rotation = _sprite.rotation
	_fit_source_visible_frame_size = _get_source_visible_frame_size()
	_apply_grid_fit_scale(true)
	_apply_direction_frame(Vector2.DOWN)
	_reset_motion_offsets()


func update_animation(move_velocity: Vector2, fallback_direction: Vector2, delta: float) -> void:
	if _sprite == null:
		return

	_apply_grid_fit_scale()

	var effective_velocity := move_velocity
	if detect_position_delta_movement and effective_velocity.length_squared() <= 1.0:
		var position_delta := _get_actor_position_delta()
		if position_delta.length_squared() > 0.01:
			var safe_delta := maxf(delta, 0.0001)
			effective_velocity = position_delta / safe_delta

	var is_moving := effective_velocity.length_squared() > 1.0
	var direction := fallback_direction

	if is_moving:
		direction = effective_velocity.normalized()
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


func sync_actor_position_without_motion() -> void:
	if _actor == null or not is_instance_valid(_actor):
		_actor = get_parent() as Node2D
	if _actor == null:
		return
	_last_actor_position = _actor.global_position
	_has_last_actor_position = true


func _get_actor_position_delta() -> Vector2:
	if _actor == null or not is_instance_valid(_actor):
		_actor = get_parent() as Node2D
	if _actor == null:
		return Vector2.ZERO
	if not _has_last_actor_position:
		_last_actor_position = _actor.global_position
		_has_last_actor_position = true
		return Vector2.ZERO
	var delta_position := _actor.global_position - _last_actor_position
	_last_actor_position = _actor.global_position
	return delta_position


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


func _apply_grid_fit_scale(force: bool = false) -> void:
	if not fit_to_room_grid or _sprite == null:
		return

	var cell_size := _get_room_map_cell_size()
	if not force and cell_size.is_equal_approx(_last_fit_cell_size):
		return

	_last_fit_cell_size = cell_size
	var source_size := _fit_source_visible_frame_size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = fit_fallback_visible_frame_size

	var target_size := Vector2(
		maxf(cell_size.x * maxf(fit_grid_cells.x, 0.1) - fit_padding_pixels.x * 2.0, 1.0),
		maxf(cell_size.y * maxf(fit_grid_cells.y, 0.1) - fit_padding_pixels.y * 2.0, 1.0)
	)
	var next_scale := minf(target_size.x / source_size.x, target_size.y / source_size.y)
	next_scale = maxf(next_scale, 0.001)

	var sign_x := -1.0 if _base_scale.x < 0.0 else 1.0
	var sign_y := -1.0 if _base_scale.y < 0.0 else 1.0
	_base_scale = Vector2(next_scale * sign_x, next_scale * sign_y)
	_sprite.scale = _base_scale


func _get_room_map_cell_size() -> Vector2:
	if _room_map == null or not is_instance_valid(_room_map):
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _room_map == null:
		return Vector2(48.0, 48.0)
	return _room_map.get_cell_size()


func _calculate_visible_frame_size() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return fit_fallback_visible_frame_size

	var image := _sprite.texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return fit_fallback_visible_frame_size

	var frames_x := maxi(_sprite.hframes, 1)
	var frames_y := maxi(_sprite.vframes, 1)
	var frame_width := maxi(int(floor(float(image.get_width()) / float(frames_x))), 1)
	var frame_height := maxi(int(floor(float(image.get_height()) / float(frames_y))), 1)
	var max_visible_width := 0
	var max_visible_height := 0

	for frame_y in range(frames_y):
		for frame_x in range(frames_x):
			var bounds := _get_visible_bounds_for_frame(image, frame_x, frame_y, frame_width, frame_height)
			if bounds.size.x > 0.0 and bounds.size.y > 0.0:
				var centered_size := _get_centered_fit_size(bounds, Vector2(float(frame_width), float(frame_height)))
				max_visible_width = maxi(max_visible_width, int(ceil(centered_size.x)))
				max_visible_height = maxi(max_visible_height, int(ceil(centered_size.y)))

	if max_visible_width <= 0 or max_visible_height <= 0:
		return Vector2(float(frame_width), float(frame_height))

	return Vector2(float(max_visible_width), float(max_visible_height))


func _get_source_visible_frame_size() -> Vector2:
	if not fit_measure_texture_alpha_bounds:
		return fit_fallback_visible_frame_size
	return _calculate_visible_frame_size()


func _get_centered_fit_size(bounds: Rect2, frame_size: Vector2) -> Vector2:
	var frame_center := frame_size * 0.5
	var left_extent := maxf(frame_center.x - bounds.position.x, 0.0)
	var right_extent := maxf(bounds.end.x - frame_center.x, 0.0)
	var top_extent := maxf(frame_center.y - bounds.position.y, 0.0)
	var bottom_extent := maxf(bounds.end.y - frame_center.y, 0.0)
	return Vector2(maxf(left_extent, right_extent) * 2.0, maxf(top_extent, bottom_extent) * 2.0)


func _get_visible_bounds_for_frame(
	image: Image,
	frame_x: int,
	frame_y: int,
	frame_width: int,
	frame_height: int
) -> Rect2:
	var min_x := frame_width
	var min_y := frame_height
	var max_x := -1
	var max_y := -1
	var origin_x := frame_x * frame_width
	var origin_y := frame_y * frame_height

	for y in range(frame_height):
		for x in range(frame_width):
			var alpha := image.get_pixel(origin_x + x, origin_y + y).a
			if alpha <= fit_alpha_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2()

	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	)


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
