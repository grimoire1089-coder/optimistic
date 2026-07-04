extends Node
class_name ExplorationLocationSystem

const DEFAULT_LOCATION_ID: StringName = &"capsule_farm_mushroom_district"
const DEFAULT_JOB_ID: StringName = &"explore_capsule_farm_mushroom_district"
const DEFAULT_DISPLAY_NAME := "カプセルファーム きのこ採取地区"
const DEFAULT_LOCATION_TEXTURE_PATH := "res://Assets/Maps/Location/Location_005.png"
const DEFAULT_BGM_PATH := "res://Assets/Audio/BGM/Forest_001.ogg"
const DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH := "res://Assets/Maps/Location/Location_001.png"

const EVENT_REWARDS: Array[Dictionary] = [
	{
		"category_id": &"ingredients",
		"item_id": &"brown_mushroom",
		"display_name": "ブラウンマッシュルーム",
		"amount_min": 1,
		"amount_max": 3,
		"icon_path": "res://Assets/Items/Icons/Mushroom/Brown mushroom.png",
		"description": "カプセルファームの湿潤ドームで採れた食用きのこ。",
		"sell_price": 18,
	},
]

@export var worker_path: NodePath = NodePath("../Robin")
@export var location_background_path: NodePath = NodePath("../LocationBackground")
@export var stay_overlay_path: NodePath = NodePath("../WorkLocationStayOverlay")
@export var location_id: StringName = DEFAULT_LOCATION_ID
@export var exploration_job_id: StringName = DEFAULT_JOB_ID
@export var display_name: String = DEFAULT_DISPLAY_NAME
@export var duration_minutes: int = 180
@export var min_duration_minutes: int = 30
@export var max_duration_minutes: int = 720
@export var duration_step_minutes: int = 30
@export var event_interval_minutes: int = 45
@export var enable_time_acceleration: bool = false
@export var exploration_time_scale: float = 1.0
@export var location_texture_path: String = DEFAULT_LOCATION_TEXTURE_PATH
@export var restore_location_texture_path: String = DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH
@export var bgm_paths: PackedStringArray = PackedStringArray([DEFAULT_BGM_PATH])

var _worker: Node
var _location_background: Node
var _stay_overlay: Node
var _active: bool = false
var _active_duration_minutes: int = 0
var _event_elapsed_minutes: float = 0.0
var _rng := RandomNumberGenerator.new()
var _previous_bgm: AudioStream
var _previous_bgm_position: float = 0.0
var _has_previous_bgm: bool = false
var _active_bgm: AudioStream
var _previous_work_fast_forward_scale: float = 8.0
var _has_previous_work_fast_forward_scale: bool = false


func _ready() -> void:
	_rng.randomize()
	_resolve_refs()
	_connect_worker_signals()
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	var game_minutes: float = _get_game_minutes_from_delta(delta)
	if game_minutes <= 0.0:
		return
	_event_elapsed_minutes += game_minutes
	var safe_interval: float = maxf(float(event_interval_minutes), 1.0)
	while _event_elapsed_minutes >= safe_interval:
		_event_elapsed_minutes -= safe_interval
		_grant_exploration_event_reward()


func request_exploration(requested_location_id: StringName, requested_duration_minutes: int = -1) -> bool:
	if requested_location_id != location_id:
		return false
	var worker: Node = _get_worker()
	if worker == null or not worker.has_method("request_work_at_entrance"):
		return false
	var safe_duration_minutes: int = get_safe_duration_minutes(requested_duration_minutes)
	_configure_worker_time_scale_for_exploration()
	var request_result: Variant = worker.call("request_work_at_entrance", exploration_job_id, display_name, safe_duration_minutes)
	if request_result == true:
		_active_duration_minutes = safe_duration_minutes
		_push_message("%sへ%d分の探索に向かいます。" % [display_name, safe_duration_minutes])
		return true
	_restore_worker_time_scale_after_exploration()
	return false


func is_exploration_job(job_id: StringName) -> bool:
	return job_id == exploration_job_id


func get_display_name_for_location(requested_location_id: StringName) -> String:
	if requested_location_id == location_id:
		return display_name
	return String(requested_location_id)


func get_default_duration_minutes() -> int:
	return get_safe_duration_minutes(duration_minutes)


func get_min_duration_minutes() -> int:
	return maxi(min_duration_minutes, 1)


func get_max_duration_minutes() -> int:
	return maxi(max_duration_minutes, get_min_duration_minutes())


func get_duration_step_minutes() -> int:
	return maxi(duration_step_minutes, 1)


func get_safe_duration_minutes(requested_duration_minutes: int) -> int:
	var base_minutes: int = requested_duration_minutes
	if base_minutes <= 0:
		base_minutes = duration_minutes
	return clampi(base_minutes, get_min_duration_minutes(), get_max_duration_minutes())


func get_duration_minutes_for_location(requested_location_id: StringName) -> int:
	if requested_location_id == location_id:
		return get_default_duration_minutes()
	return 0


func _on_worker_work_started(job_id: StringName) -> void:
	if job_id != exploration_job_id:
		return
	_active = true
	_event_elapsed_minutes = 0.0
	_apply_exploration_location_card()
	_play_exploration_bgm()
	_show_exploration_overlay()
	_push_message("探索を開始しました: %s / %d分" % [display_name, _active_duration_minutes])


func _on_worker_work_completed(job_id: StringName) -> void:
	if job_id != exploration_job_id:
		return
	_active = false
	_event_elapsed_minutes = 0.0
	_active_duration_minutes = 0
	_hide_exploration_overlay()
	_restore_location_card()
	_restore_previous_bgm_if_needed()
	_restore_worker_time_scale_after_exploration()
	_push_message("探索から帰ってきました: %s" % display_name)


func _grant_exploration_event_reward() -> void:
	if EVENT_REWARDS.is_empty():
		return
	var inventory: Node = _get_worker_inventory_module()
	if inventory == null or not inventory.has_method("add_item"):
		_push_message("探索イベントが発生しましたが、インベントリが見つかりません。")
		return

	var reward: Dictionary = EVENT_REWARDS[_rng.randi_range(0, EVENT_REWARDS.size() - 1)]
	var amount_min: int = maxi(int(reward.get("amount_min", 1)), 1)
	var amount_max: int = maxi(int(reward.get("amount_max", amount_min)), amount_min)
	var amount: int = _rng.randi_range(amount_min, amount_max)
	var category_id: StringName = _to_string_name(reward.get("category_id", &"ingredients"))
	var item_id: StringName = _to_string_name(reward.get("item_id", &""))
	var item_name: String = String(reward.get("display_name", String(item_id)))
	var icon_path: String = String(reward.get("icon_path", ""))
	var description: String = String(reward.get("description", ""))
	var sell_price: int = int(reward.get("sell_price", 0))

	if item_id == &"":
		return

	var add_result: Variant = inventory.call(
		"add_item",
		category_id,
		item_id,
		item_name,
		amount,
		icon_path,
		99,
		description,
		0,
		sell_price
	)
	var added: bool = add_result == true

	if added:
		_push_message("探索イベント: %s x%d を見つけました。" % [item_name, amount])
	else:
		_push_message("探索イベント: %s を見つけましたが、インベントリに空きがありません。" % item_name)


func _configure_worker_time_scale_for_exploration() -> void:
	var behavior: Node = _get_worker_entrance_behavior()
	if behavior == null:
		return
	if not _has_property(behavior, &"work_fast_forward_scale"):
		return
	if not _has_previous_work_fast_forward_scale:
		_previous_work_fast_forward_scale = float(behavior.get("work_fast_forward_scale"))
		_has_previous_work_fast_forward_scale = true
	var next_scale: float = exploration_time_scale if enable_time_acceleration else 1.0
	behavior.set("work_fast_forward_scale", maxf(next_scale, 1.0))


func _restore_worker_time_scale_after_exploration() -> void:
	if not _has_previous_work_fast_forward_scale:
		return
	var behavior: Node = _get_worker_entrance_behavior()
	if behavior != null and _has_property(behavior, &"work_fast_forward_scale"):
		behavior.set("work_fast_forward_scale", _previous_work_fast_forward_scale)
	_has_previous_work_fast_forward_scale = false
	_previous_work_fast_forward_scale = 8.0


func _apply_exploration_location_card() -> void:
	var background: Node = _get_location_background()
	if background == null:
		return
	if background.has_method("set_texture_path"):
		background.call("set_texture_path", location_texture_path)
	else:
		background.set("texture_path", location_texture_path)


func _restore_location_card() -> void:
	var background: Node = _get_location_background()
	if background == null:
		return
	if background.has_method("set_texture_path"):
		background.call("set_texture_path", restore_location_texture_path)
	else:
		background.set("texture_path", restore_location_texture_path)


func _show_exploration_overlay() -> void:
	var overlay: Node = _get_stay_overlay()
	if overlay == null:
		return
	var worker_name: String = _get_worker_display_name()
	if overlay.has_method("show_exploration_stay"):
		overlay.call("show_exploration_stay", exploration_job_id, display_name, worker_name)
	elif overlay.has_method("show_work_stay"):
		overlay.call("show_work_stay", exploration_job_id, display_name, worker_name)


func _hide_exploration_overlay() -> void:
	var overlay: Node = _get_stay_overlay()
	if overlay == null:
		return
	if overlay.has_method("hide_work_stay"):
		overlay.call("hide_work_stay")


func _play_exploration_bgm() -> void:
	var stream: AudioStream = _get_random_bgm_stream()
	if stream == null:
		return
	var audio_player: Node = get_node_or_null("/root/AudioPlayer")
	if audio_player == null or not audio_player.has_method("play_bgm"):
		return
	if not _has_previous_bgm:
		if audio_player.has_method("get_current_bgm"):
			_previous_bgm = audio_player.call("get_current_bgm") as AudioStream
		else:
			_previous_bgm = null
		if audio_player.has_method("get_bgm_playback_position"):
			_previous_bgm_position = float(audio_player.call("get_bgm_playback_position"))
		else:
			_previous_bgm_position = 0.0
		_has_previous_bgm = true
	_ensure_stream_loop(stream)
	audio_player.call("play_bgm", stream, 0.0, false)
	_active_bgm = stream


func _restore_previous_bgm_if_needed() -> void:
	if not _has_previous_bgm:
		_active_bgm = null
		return
	var audio_player: Node = get_node_or_null("/root/AudioPlayer")
	if audio_player != null:
		if _previous_bgm != null and audio_player.has_method("play_bgm"):
			audio_player.call("play_bgm", _previous_bgm, _previous_bgm_position, true)
		elif audio_player.has_method("stop_bgm"):
			audio_player.call("stop_bgm")
	_previous_bgm = null
	_previous_bgm_position = 0.0
	_has_previous_bgm = false
	_active_bgm = null


func _get_random_bgm_stream() -> AudioStream:
	if bgm_paths.is_empty():
		return null
	var attempts: int = bgm_paths.size()
	for _i in attempts:
		var bgm_path: String = String(bgm_paths[_rng.randi_range(0, bgm_paths.size() - 1)])
		if bgm_path.is_empty() or not ResourceLoader.exists(bgm_path):
			continue
		return load(bgm_path) as AudioStream
	return null


func _ensure_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", true)
			return


func _get_game_minutes_from_delta(delta: float) -> float:
	var game_clock: Node = get_node_or_null("/root/GameClock")
	if game_clock != null and game_clock.has_method("get"):
		var seconds_per_minute: float = float(game_clock.get("real_seconds_per_game_minute"))
		if seconds_per_minute > 0.0:
			return delta / seconds_per_minute
	return delta


func _get_worker_inventory_module() -> Node:
	var worker: Node = _get_worker()
	if worker == null:
		return null
	if worker.has_method("get_inventory_module"):
		return worker.call("get_inventory_module") as Node
	return worker.get_node_or_null("RobinInventoryModule")


func _get_worker_entrance_behavior() -> Node:
	var worker: Node = _get_worker()
	if worker == null:
		return null
	return worker.get_node_or_null("AICharacterEntranceTravelBehaviorModule")


func _get_worker_display_name() -> String:
	var worker: Node = _get_worker()
	if worker == null:
		return "ロビン"
	var value: Variant = worker.get("display_name")
	var name: String = String(value)
	if name.is_empty():
		return "ロビン"
	return name


func _get_worker() -> Node:
	if _worker != null and is_instance_valid(_worker):
		return _worker
	_resolve_refs()
	_connect_worker_signals()
	return _worker


func _get_location_background() -> Node:
	if _location_background != null and is_instance_valid(_location_background):
		return _location_background
	_resolve_refs()
	return _location_background


func _get_stay_overlay() -> Node:
	if _stay_overlay != null and is_instance_valid(_stay_overlay):
		return _stay_overlay
	_resolve_refs()
	return _stay_overlay


func _connect_worker_signals() -> void:
	if _worker == null or not is_instance_valid(_worker):
		return
	var started_callable := Callable(self, "_on_worker_work_started")
	if _worker.has_signal(&"work_started") and not _worker.is_connected(&"work_started", started_callable):
		_worker.connect(&"work_started", started_callable)
	var completed_callable := Callable(self, "_on_worker_work_completed")
	if _worker.has_signal(&"work_completed") and not _worker.is_connected(&"work_completed", completed_callable):
		_worker.connect(&"work_completed", completed_callable)


func _resolve_refs() -> void:
	if _worker == null and not worker_path.is_empty():
		_worker = get_node_or_null(worker_path)
	if _location_background == null and not location_background_path.is_empty():
		_location_background = get_node_or_null(location_background_path)
	if _stay_overlay == null and not stay_overlay_path.is_empty():
		_stay_overlay = get_node_or_null(stay_overlay_path)


func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(String(property_info.get("name", ""))) == property_name:
			return true
	return false


func _push_message(message: String) -> void:
	var message_log := get_tree().get_first_node_in_group(&"message_log") as MessageLogPanel
	if message_log == null:
		return
	message_log.add_message(message)
