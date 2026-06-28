extends Node
class_name RobinRandomWanderModule

@export var walk_speed: float = 80.0
@export var screen_margin: float = 96.0
@export var idle_chance: float = 0.25
@export var idle_time_range: Vector2 = Vector2(0.4, 1.0)
@export var walk_time_range: Vector2 = Vector2(1.0, 2.2)

var _body: Node2D
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _is_idle: bool = false
var _direction: Vector2 = Vector2.DOWN

const WALK_DIRECTIONS: Array[Vector2] = [
	Vector2.DOWN,
	Vector2(1.0, 1.0).normalized(),
	Vector2.RIGHT,
	Vector2(1.0, -1.0).normalized(),
	Vector2.UP,
	Vector2(-1.0, -1.0).normalized(),
	Vector2.LEFT,
	Vector2(-1.0, 1.0).normalized(),
]


func setup(body: Node2D) -> void:
	_body = body
	_rng.randomize()
	_pick_next_action()


func get_velocity(delta: float) -> Vector2:
	if _body == null:
		return Vector2.ZERO

	_timer -= delta
	if _timer <= 0.0:
		_pick_next_action()

	_keep_inside_screen()

	if _is_idle:
		return Vector2.ZERO

	return _direction * walk_speed


func get_facing_direction() -> Vector2:
	return _direction


func _pick_next_action() -> void:
	_is_idle = _rng.randf() < idle_chance

	if _is_idle:
		_timer = _rng.randf_range(idle_time_range.x, idle_time_range.y)
		return

	_timer = _rng.randf_range(walk_time_range.x, walk_time_range.y)
	_direction = WALK_DIRECTIONS[_rng.randi_range(0, WALK_DIRECTIONS.size() - 1)]


func _keep_inside_screen() -> void:
	var rect := _body.get_viewport().get_visible_rect()
	var min_pos := rect.position + Vector2(screen_margin, screen_margin)
	var max_pos := rect.end - Vector2(screen_margin, screen_margin)
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
