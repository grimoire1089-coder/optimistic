extends Node
class_name RobinRandomWanderModule

@export var walk_speed: float = 80.0
@export var screen_margin: float = 96.0
@export var side_ui_margin: float = 280.0
@export var movement_area_provider_path: NodePath
@export var idle_chance: float = 0.25
@export var idle_time_range: Vector2 = Vector2(0.4, 1.0)
@export var walk_time_range: Vector2 = Vector2(1.0, 2.2)

# 枠線からキャラクター画像がはみ出さないよう、原点の移動範囲を内側へ縮める量です。
# 物理コリジョンではなく、見た目サイズ用の余白です。
@export var visual_half_extents: Vector2 = Vector2(48.0, 76.0)
@export var keep_visual_inside_frame: bool = true

var _body: Node2D
var _movement_area_provider: Node
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _is_idle: bool = false
var _direction: Vector2 = Vector2.DOWN
var _walk_directions: Array[Vector2] = []


func setup(body: Node2D) -> void:
	_body = body
	_resolve_movement_area_provider()
	_rng.randomize()
	_setup_walk_directions()
	_pick_next_action()


func set_movement_area_provider_path(next_provider_path: NodePath) -> void:
	if movement_area_provider_path == next_provider_path:
		_resolve_movement_area_provider()
		return
	movement_area_provider_path = next_provider_path
	_movement_area_provider = null
	_resolve_movement_area_provider()
	_pick_next_action()
	clamp_body_to_movement_area()


func get_velocity(delta: float) -> Vector2:
	if _body == null:
		return Vector2.ZERO

	_timer -= delta
	if _timer <= 0.0:
		_pick_next_action()

	_keep_inside_movement_area()

	if _is_idle:
		return Vector2.ZERO

	return _direction * walk_speed


func get_facing_direction() -> Vector2:
	return _direction


func get_movement_center() -> Vector2:
	if _body == null:
		return Vector2.ZERO

	var movement_area := get_movement_area()
	return movement_area.position + movement_area.size * 0.5


func get_visual_movement_area() -> Rect2:
	var provider_area := _get_provider_visual_map_rect()
	if provider_area.size.x > 0.0 and provider_area.size.y > 0.0:
		return provider_area

	if _body == null:
		return Rect2()

	var rect := _body.get_viewport().get_visible_rect()
	var min_pos := rect.position + Vector2(side_ui_margin, screen_margin)
	var max_pos := rect.end - Vector2(side_ui_margin, screen_margin)
	var center := rect.position + rect.size * 0.5

	if min_pos.x > max_pos.x:
		min_pos.x = center.x
		max_pos.x = center.x

	if min_pos.y > max_pos.y:
		min_pos.y = center.y
		max_pos.y = center.y

	var available_size := max_pos - min_pos
	available_size.x = maxf(available_size.x, 0.0)
	available_size.y = maxf(available_size.y, 0.0)

	var square_size := minf(available_size.x, available_size.y)
	var square_area_size := Vector2(square_size, square_size)
	var square_area_position := min_pos + (available_size - square_area_size) * 0.5
	return Rect2(square_area_position, square_area_size)


func get_movement_area() -> Rect2:
	var visual_area := get_visual_movement_area()
	if not keep_visual_inside_frame:
		return visual_area

	return _get_inset_area_for_actor_origin(visual_area)


func clamp_body_to_movement_area() -> bool:
	if _body == null:
		return false

	var movement_area := get_movement_area()
	var area_end := movement_area.end
	var current_position := _body.global_position
	var clamped_position := Vector2(
		clampf(current_position.x, movement_area.position.x, area_end.x),
		clampf(current_position.y, movement_area.position.y, area_end.y)
	)

	if current_position.distance_squared_to(clamped_position) <= 0.001:
		return false

	_body.global_position = clamped_position
	return true


func _get_inset_area_for_actor_origin(area: Rect2) -> Rect2:
	var inset_x := minf(visual_half_extents.x, area.size.x * 0.5)
	var inset_y := minf(visual_half_extents.y, area.size.y * 0.5)
	var inset_position := area.position + Vector2(inset_x, inset_y)
	var inset_size := area.size - Vector2(inset_x * 2.0, inset_y * 2.0)
	inset_size.x = maxf(inset_size.x, 0.0)
	inset_size.y = maxf(inset_size.y, 0.0)
	return Rect2(inset_position, inset_size)


func _setup_walk_directions() -> void:
	if not _walk_directions.is_empty():
		return

	_walk_directions = [
		Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(),
		Vector2.RIGHT,
		Vector2(1.0, -1.0).normalized(),
		Vector2.UP,
		Vector2(-1.0, -1.0).normalized(),
		Vector2.LEFT,
		Vector2(-1.0, 1.0).normalized(),
	]


func _pick_next_action() -> void:
	_setup_walk_directions()
	_is_idle = _rng.randf() < idle_chance

	if _is_idle:
		_timer = _rng.randf_range(idle_time_range.x, idle_time_range.y)
		return

	_timer = _rng.randf_range(walk_time_range.x, walk_time_range.y)
	_direction = _walk_directions[_rng.randi_range(0, _walk_directions.size() - 1)]


func _keep_inside_movement_area() -> void:
	var movement_area := get_movement_area()
	var min_pos := movement_area.position
	var max_pos := movement_area.end
	var position := _body.global_position
	var target_direction := Vector2.ZERO

	if position.x < min_pos.x:
		target_direction.x = 1.0
	elif position.x > max_pos.x:
		target_direction.x = -1.0

	if position.y < min_pos.y:
		target_direction.y = 1.0
	elif position.y > max_pos.y:
		target_direction.y = -1.0

	if target_direction != Vector2.ZERO:
		_direction = target_direction.normalized()
		_is_idle = false
		_timer = max(_timer, 0.35)


func _get_provider_visual_map_rect() -> Rect2:
	_resolve_movement_area_provider()
	if _movement_area_provider == null:
		return Rect2()
	if not _movement_area_provider.has_method("get_visual_map_rect"):
		return Rect2()
	var provider_area: Rect2 = _movement_area_provider.call("get_visual_map_rect")
	return provider_area


func _resolve_movement_area_provider() -> void:
	if _movement_area_provider != null:
		return
	if movement_area_provider_path.is_empty():
		return

	_movement_area_provider = get_node_or_null(movement_area_provider_path)
	if _movement_area_provider != null:
		return

	if _body != null:
		_movement_area_provider = _body.get_node_or_null(movement_area_provider_path)
