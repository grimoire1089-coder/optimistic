extends Node
class_name RobinWalkSpriteAnimator

@export var sprite_path: NodePath = NodePath("../Sprite2D")
@export var frames_per_second: float = 6.0
@export var idle_frame: int = 1

var _sprite: Sprite2D
var _frame_timer: float = 0.0
var _walk_frame: int = 1
var _last_direction: Vector2 = Vector2.DOWN

const DIRECTION_ROWS := [
	{"direction": Vector2.DOWN, "row": 0},
	{"direction": Vector2(1.0, 1.0).normalized(), "row": 1},
	{"direction": Vector2.RIGHT, "row": 2},
	{"direction": Vector2(1.0, -1.0).normalized(), "row": 3},
	{"direction": Vector2.UP, "row": 4},
	{"direction": Vector2(-1.0, -1.0).normalized(), "row": 5},
	{"direction": Vector2.LEFT, "row": 6},
	{"direction": Vector2(-1.0, 1.0).normalized(), "row": 7},
]


func setup() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		push_warning("RobinWalkSpriteAnimator: Sprite2D が見つかりません。")
		return

	_sprite.hframes = 3
	_sprite.vframes = 8
	_apply_frame(idle_frame, 0)


func update_animation(move_velocity: Vector2, fallback_direction: Vector2, delta: float) -> void:
	if _sprite == null:
		return

	var is_moving := move_velocity.length_squared() > 1.0
	var direction := fallback_direction
	if is_moving:
		direction = move_velocity.normalized()
		_last_direction = direction
	elif direction.length_squared() <= 0.001:
		direction = _last_direction

	var row := _direction_to_row(direction)

	if not is_moving:
		_apply_frame(idle_frame, row)
		return

	_frame_timer += delta
	var frame_duration := 1.0 / max(frames_per_second, 0.1)
	if _frame_timer >= frame_duration:
		_frame_timer = 0.0
		_walk_frame = (_walk_frame + 1) % 3

	_apply_frame(_walk_frame, row)


func _apply_frame(frame_index: int, row: int) -> void:
	_sprite.frame_coords = Vector2i(clamp(frame_index, 0, 2), clamp(row, 0, 7))


func _direction_to_row(direction: Vector2) -> int:
	if direction.length_squared() <= 0.001:
		direction = Vector2.DOWN

	var normalized_direction := direction.normalized()
	var best_row := 0
	var best_dot := -999.0

	for item in DIRECTION_ROWS:
		var dot_value: float = normalized_direction.dot(item["direction"])
		if dot_value > best_dot:
			best_dot = dot_value
			best_row = item["row"]

	return best_row
