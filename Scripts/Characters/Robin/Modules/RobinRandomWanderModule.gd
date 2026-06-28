extends Node
class_name RobinRandomWanderModule

@export var walk_speed: float = 80.0
@export var screen_margin: float = 96.0
@export var side_ui_margin: float = 280.0
@export var idle_chance: float = 0.25
@export var idle_time_range: Vector2 = Vector2(0.4, 1.0)
@export var walk_time_range: Vector2 = Vector2(1.0, 2.2)

var _body: Node2D
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _is_idle: bool = false
var _direction: Vector2 = Vector2.DOWN
var _walk_directions: Array[Vector2] = []


func setup(body: Node2D) -> void:
	_body = body
	_rng.randomize()
	_setup_walk_directions()
	_pick_next_action()


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

	var movement_area := _get_movement_area()
	return movement_area.position + movement_area.size * 0.5


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
	var movement_area := _get_movement_area()
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


func _get_movement_area() -> Rect2:
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

	return Rect2(min_pos, max_pos - min_pos)
