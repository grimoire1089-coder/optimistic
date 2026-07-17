extends Node
class_name AICharacterShowerPresentationModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)

@export var visual_node_path: NodePath = NodePath("Sprite2D")
@export var shower_sfx_path: String = "res://Assets/Audio/SFX/Game/Shower.ogg"
@export var shower_sfx_volume_db: float = 0.0
@export var ai_actor_group_name: StringName = &"ai_character_actor"

var _body: CharacterBody2D
var _room_map: RoomMapGridModule
var _furniture_placement_module: Node
var _visual_node: CanvasItem
var _actor_grid_footprint: Vector2i = Vector2i(2, 4)
var _shower_sfx: AudioStream
var _shower_sfx_player: AudioStreamPlayer
var _return_grid_position: Vector2i = INVALID_GRID_POSITION
var _return_world_position := Vector2.ZERO
var _return_visual_visible := true
var _is_presenting := false


func setup(
	body: CharacterBody2D,
	room_map: RoomMapGridModule,
	furniture_placement_module: Node,
	actor_grid_footprint: Vector2i
) -> void:
	_body = body
	_room_map = room_map
	_furniture_placement_module = furniture_placement_module
	_actor_grid_footprint = AICharacterGridMovementHelper.get_safe_footprint(actor_grid_footprint)
	_resolve_visual_node()


func _exit_tree() -> void:
	end_shower()
	_stop_shower_sfx()


func begin_shower(shower: Node2D) -> void:
	if shower == null or not is_instance_valid(shower):
		return
	if _body == null or not is_instance_valid(_body):
		return
	if _is_presenting:
		end_shower()

	_resolve_visual_node()
	_return_world_position = _body.global_position
	_return_grid_position = _get_body_top_left_grid_position(_return_world_position)
	var has_valid_visual := _visual_node != null and is_instance_valid(_visual_node)
	_return_visual_visible = _visual_node.visible if has_valid_visual else true
	_is_presenting = true

	_body.velocity = Vector2.ZERO
	if has_valid_visual:
		_visual_node.hide()
	_body.global_position = shower.global_position
	_body.reset_physics_interpolation()
	_start_shower_sfx()


func end_shower() -> void:
	if not _is_presenting:
		return
	_is_presenting = false
	_stop_shower_sfx()

	if _body != null and is_instance_valid(_body):
		var exit_cell := _resolve_exit_grid_position()
		if _is_valid_grid_position(exit_cell) and _room_map != null:
			_body.global_position = _room_map.grid_to_world_area_center(exit_cell, _actor_grid_footprint)
		else:
			_body.global_position = _return_world_position
		_body.velocity = Vector2.ZERO
		_body.reset_physics_interpolation()

	if _visual_node != null and is_instance_valid(_visual_node):
		_visual_node.visible = _return_visual_visible

	_return_grid_position = INVALID_GRID_POSITION
	_return_world_position = Vector2.ZERO


func is_presenting() -> bool:
	return _is_presenting


func _resolve_exit_grid_position() -> Vector2i:
	if _room_map == null:
		return INVALID_GRID_POSITION
	if _is_valid_grid_position(_return_grid_position) and _is_exit_grid_position_available(_return_grid_position, _actor_grid_footprint):
		return _return_grid_position
	return AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		_return_world_position,
		_actor_grid_footprint,
		Callable(self, "_is_exit_grid_position_available"),
		INVALID_GRID_POSITION
	)


func _is_exit_grid_position_available(top_left_cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null or not _room_map.is_grid_area_inside(top_left_cell, footprint):
		return false
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		if _furniture_placement_module.call("can_place_at", top_left_cell, footprint) != true:
			return false
	return not _has_other_ai_in_grid_area(top_left_cell, footprint)


func _has_other_ai_in_grid_area(top_left_cell: Vector2i, footprint: Vector2i) -> bool:
	if _body == null or _body.get_tree() == null or _room_map == null:
		return false
	for actor in _body.get_tree().get_nodes_in_group(ai_actor_group_name):
		var other_actor := actor as Node2D
		if other_actor == null or other_actor == _body:
			continue
		var other_footprint := _get_actor_footprint(other_actor)
		var other_top_left := AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
			_room_map,
			other_actor.global_position,
			other_footprint,
			INVALID_GRID_POSITION
		)
		if not _is_valid_grid_position(other_top_left):
			continue
		if _grid_areas_overlap(top_left_cell, footprint, other_top_left, other_footprint):
			return true
	return false


func _get_actor_footprint(actor: Node2D) -> Vector2i:
	if actor != null and actor.has_method("get_actor_grid_footprint"):
		var value: Variant = actor.call("get_actor_grid_footprint")
		if value is Vector2i:
			var typed_value: Vector2i = value
			return AICharacterGridMovementHelper.get_safe_footprint(typed_value)
	return _actor_grid_footprint


func _grid_areas_overlap(
	a_top_left: Vector2i,
	a_footprint: Vector2i,
	b_top_left: Vector2i,
	b_footprint: Vector2i
) -> bool:
	return (
		a_top_left.x < b_top_left.x + b_footprint.x
		and a_top_left.x + a_footprint.x > b_top_left.x
		and a_top_left.y < b_top_left.y + b_footprint.y
		and a_top_left.y + a_footprint.y > b_top_left.y
	)


func _get_body_top_left_grid_position(world_position: Vector2) -> Vector2i:
	return AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
		_room_map,
		world_position,
		_actor_grid_footprint,
		INVALID_GRID_POSITION
	)


func _start_shower_sfx() -> void:
	_load_shower_sfx_if_needed()
	_ensure_shower_sfx_player()
	if _shower_sfx == null or _shower_sfx_player == null:
		return
	_shower_sfx_player.stream = _shower_sfx
	_shower_sfx_player.volume_db = shower_sfx_volume_db
	_shower_sfx_player.play()


func _stop_shower_sfx() -> void:
	if _shower_sfx_player == null or not is_instance_valid(_shower_sfx_player):
		return
	if _shower_sfx_player.playing:
		_shower_sfx_player.stop()


func _on_shower_sfx_finished() -> void:
	if not _is_presenting:
		return
	if _shower_sfx_player == null or _shower_sfx == null:
		return
	_shower_sfx_player.play()


func _load_shower_sfx_if_needed() -> void:
	if _shower_sfx != null or shower_sfx_path.is_empty():
		return
	if not ResourceLoader.exists(shower_sfx_path):
		return
	_shower_sfx = load(shower_sfx_path) as AudioStream


func _ensure_shower_sfx_player() -> void:
	if _shower_sfx_player != null and is_instance_valid(_shower_sfx_player):
		return
	_shower_sfx_player = AudioStreamPlayer.new()
	_shower_sfx_player.name = "ShowerSfxPlayer"
	add_child(_shower_sfx_player)
	var callable := Callable(self, "_on_shower_sfx_finished")
	if not _shower_sfx_player.finished.is_connected(callable):
		_shower_sfx_player.finished.connect(callable)


func _resolve_visual_node() -> void:
	if _visual_node != null and is_instance_valid(_visual_node):
		return
	if _body == null or visual_node_path.is_empty():
		return
	_visual_node = _body.get_node_or_null(visual_node_path) as CanvasItem


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return AICharacterGridMovementHelper.is_valid_grid_position(grid_position, INVALID_GRID_POSITION)
