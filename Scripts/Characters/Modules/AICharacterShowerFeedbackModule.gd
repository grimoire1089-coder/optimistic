extends Node
class_name AICharacterShowerFeedbackModule

@export var hygiene_behavior_path: NodePath = NodePath("../AICharacterHygieneBehaviorModule")
@export var visual_node_path: NodePath = NodePath("../Sprite2D")
@export var needs_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterNeedsModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var hygiene_need_id: StringName = CharacterNeedIds.HYGIENE
@export var shower_ids: Array[StringName] = [&"shower"]
@export_range(0.0, 1.0, 0.01) var hygiene_request_ratio: float = 0.45
@export_range(0.0, 1.0, 0.01) var shower_visual_alpha: float = 0.0
@export var shower_sfx_path: String = "res://Assets/Audio/SFX/Game/Shower.ogg"
@export var shower_sfx_volume_db: float = 0.0
@export var log_missing_shower: bool = true
@export var missing_shower_log_cooldown_seconds: float = 5.0

var _hygiene_behavior: Node
var _visual_node: CanvasItem
var _needs_module: CharacterNeedsModule
var _furniture_root: Node
var _shower_sfx: AudioStream
var _shower_sfx_player: AudioStreamPlayer
var _visual_original_modulate: Color = Color.WHITE
var _visual_alpha_applied := false
var _missing_shower_log_timer := 0.0


func _ready() -> void:
	_resolve_refs()
	set_process(true)


func _process(delta: float) -> void:
	_resolve_refs()
	_tick_missing_shower_log_cooldown(delta)

	if _is_showering():
		_apply_shower_visual_alpha()
		_ensure_shower_sfx_playing()
		return

	_restore_shower_visual_alpha()
	_stop_shower_sfx()
	_log_missing_shower_if_needed()


func _exit_tree() -> void:
	_restore_shower_visual_alpha()
	_stop_shower_sfx()


func _is_showering() -> bool:
	if _hygiene_behavior == null:
		return false
	if not _hygiene_behavior.has_method("is_showering"):
		return false
	return _hygiene_behavior.call("is_showering") == true


func _apply_shower_visual_alpha() -> void:
	if _visual_node == null or not is_instance_valid(_visual_node):
		return
	if not _visual_alpha_applied:
		_visual_original_modulate = _visual_node.modulate
		_visual_alpha_applied = true
	var next_modulate := _visual_node.modulate
	next_modulate.a = clampf(shower_visual_alpha, 0.0, 1.0)
	_visual_node.modulate = next_modulate


func _restore_shower_visual_alpha() -> void:
	if not _visual_alpha_applied:
		return
	if _visual_node != null and is_instance_valid(_visual_node):
		_visual_node.modulate = _visual_original_modulate
	_visual_alpha_applied = false


func _ensure_shower_sfx_playing() -> void:
	_load_shower_sfx_if_needed()
	_ensure_shower_sfx_player()
	if _shower_sfx == null or _shower_sfx_player == null:
		return
	if _shower_sfx_player.stream != _shower_sfx:
		_shower_sfx_player.stream = _shower_sfx
	_shower_sfx_player.volume_db = shower_sfx_volume_db
	if not _shower_sfx_player.playing:
		_shower_sfx_player.play()


func _stop_shower_sfx() -> void:
	if _shower_sfx_player == null or not is_instance_valid(_shower_sfx_player):
		return
	if _shower_sfx_player.playing:
		_shower_sfx_player.stop()


func _load_shower_sfx_if_needed() -> void:
	if _shower_sfx != null:
		return
	if shower_sfx_path.is_empty():
		return
	if not ResourceLoader.exists(shower_sfx_path):
		return
	var resource := load(shower_sfx_path)
	if resource is AudioStream:
		_shower_sfx = resource


func _ensure_shower_sfx_player() -> void:
	if _shower_sfx_player != null and is_instance_valid(_shower_sfx_player):
		return
	_shower_sfx_player = AudioStreamPlayer.new()
	_shower_sfx_player.name = "ShowerSfxPlayer"
	add_child(_shower_sfx_player)


func _log_missing_shower_if_needed() -> void:
	if not log_missing_shower:
		return
	if _missing_shower_log_timer > 0.0:
		return
	if _needs_module == null:
		return
	if _needs_module.get_need_ratio(hygiene_need_id, 1.0) > hygiene_request_ratio:
		return
	if _has_hygiene_shower_furniture():
		return

	var hygiene_percent := _needs_module.get_need_ratio(hygiene_need_id, 0.0) * 100.0
	_emit_debug_message("[AI Hygiene] シャワー家具が見つかりません hygiene=%.1f%% 配置: ビルド > 衛生 > シャワー" % hygiene_percent)
	_missing_shower_log_timer = maxf(missing_shower_log_cooldown_seconds, 0.1)


func _has_hygiene_shower_furniture() -> bool:
	if _furniture_root == null:
		return false
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if _is_shower_furniture(furniture):
			return true
	return false


func _is_shower_furniture(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("can_restore_hygiene") and furniture.call("can_restore_hygiene") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if shower_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if shower_ids.has(property_id):
			return true
	return false


func _tick_missing_shower_log_cooldown(delta: float) -> void:
	if _missing_shower_log_timer <= 0.0:
		return
	_missing_shower_log_timer = maxf(_missing_shower_log_timer - maxf(delta, 0.0), 0.0)


func _emit_debug_message(message: String) -> void:
	var log_node: Node = get_tree().get_first_node_in_group(&"message_log")
	if log_node != null and log_node.has_method("add_debug_message"):
		log_node.call("add_debug_message", message)
	else:
		print(message)


func _resolve_refs() -> void:
	if (_hygiene_behavior == null or not is_instance_valid(_hygiene_behavior)) and not hygiene_behavior_path.is_empty():
		_hygiene_behavior = get_node_or_null(hygiene_behavior_path)
	if (_visual_node == null or not is_instance_valid(_visual_node)) and not visual_node_path.is_empty():
		_visual_node = get_node_or_null(visual_node_path) as CanvasItem
	if (_needs_module == null or not is_instance_valid(_needs_module)) and not needs_module_path.is_empty():
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if (_furniture_root == null or not is_instance_valid(_furniture_root)) and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false
