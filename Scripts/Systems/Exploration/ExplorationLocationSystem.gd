extends Node
class_name ExplorationLocationSystem

const DEFAULT_LOCATION_ID: StringName = &"capsule_farm_mushroom_district"
const DEFAULT_JOB_ID: StringName = &"explore_capsule_farm_mushroom_district"
const DEFAULT_DISPLAY_NAME := "カプセルファーム きのこ採取地区"
const DEFAULT_LOCATION_TEXTURE_PATH := "res://Assets/Maps/Location/Location_005.png"
const DEFAULT_BGM_PATH := "res://Assets/Audio/BGM/Forest_001.ogg"
const DEFAULT_BGM_2_PATH := "res://Assets/Audio/BGM/Forest_002.ogg"
const DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH := "res://Assets/Maps/Location/Location_001.png"
const DEFAULT_GATHERING_TABLE_PATH := "res://Data/Exploration/GatheringTables/CapsuleFarmMushroomDistrictGatheringTable.tres"
const GATHERING_EFFECT_MODULE_SCRIPT_PATH := "res://Scripts/Systems/Exploration/ExplorationGatheringEffectModule.gd"
const SKILL_GATHERING: StringName = &"gathering"
const SKILL_UPGRADE_GATHERING_AMOUNT_PLUS: StringName = &"gathering_amount_plus"

@export var worker_path: NodePath = NodePath("../Robin")
@export var skills_module_path: NodePath = NodePath("../Robin/AICharacterSkillsModule")
@export var location_background_path: NodePath = NodePath("../LocationBackground")
@export var stay_overlay_path: NodePath = NodePath("../WorkLocationStayOverlay")
@export var gathering_effect_module_path: NodePath = NodePath("../ExplorationGatheringEffectModule")
@export var location_id: StringName = DEFAULT_LOCATION_ID
@export var exploration_job_id: StringName = DEFAULT_JOB_ID
@export var display_name: String = DEFAULT_DISPLAY_NAME
@export var duration_minutes: int = 180
@export var min_duration_minutes: int = 30
@export var max_duration_minutes: int = 720
@export var duration_step_minutes: int = 30
@export var event_interval_minutes: int = 45
@export var gathering_experience_per_event: int = 5
@export var gathering_amount_bonus_level_step: int = 10
@export var gathering_amount_bonus_max: int = 10
@export var gathering_effect_source_offset: Vector2 = Vector2(-18.0, 18.0)
@export var enable_time_acceleration: bool = false
@export var exploration_time_scale: float = 1.0
@export var exploration_body_position_ratio: Vector2 = Vector2(0.50, 0.42)
@export var gathering_table_path: String = DEFAULT_GATHERING_TABLE_PATH
@export var location_texture_path: String = DEFAULT_LOCATION_TEXTURE_PATH
@export var restore_location_texture_path: String = DEFAULT_LOCATION_BACKGROUND_TEXTURE_PATH
@export var bgm_paths: PackedStringArray = PackedStringArray([DEFAULT_BGM_PATH, DEFAULT_BGM_2_PATH])

var _worker: Node
var _skills_module: Node
var _location_background: Node
var _stay_overlay: Node
var _gathering_effect_module: Node
var _gathering_table: Resource
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
var _previous_work_location_body_position_ratio: Vector2 = Vector2(0.44, 0.58)
var _has_previous_work_location_body_position_ratio: bool = false


func _ready() -> void:
	_rng.randomize()
	_resolve_refs()
	_connect_worker_signals()
	_ensure_gathering_effect_module()
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
	_configure_worker_presentation_for_exploration()
	var request_result: Variant = worker.call("request_work_at_entrance", exploration_job_id, display_name, safe_duration_minutes)
	if request_result == true:
		_active_duration_minutes = safe_duration_minutes
		_push_message("%sへ%d分の探索に向かいます。" % [display_name, safe_duration_minutes])
		return true
	_restore_worker_presentation_after_exploration()
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
	_restore_worker_presentation_after_exploration()
	_push_message("探索から帰ってきました: %s" % display_name)


func _grant_exploration_event_reward() -> void:
	var table: Resource = _get_gathering_table()
	var gathering_level: int = _get_gathering_level()
	if table == null or _is_gathering_table_empty(table, gathering_level):
		_push_message("探索イベントが発生しましたが、採取Lv%dで採れる食材がありません。" % gathering_level)
		return

	var inventory: Node = _get_worker_inventory_module()
	if inventory == null:
		_push_message("探索イベントが発生しましたが、インベントリが見つかりません。")
		return

	var item_path: String = _get_random_gathering_item_path(table, gathering_level)
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		_push_message("探索イベントが発生しましたが、食材データが見つかりません。")
		return

	var food_data: FoodItemData = load(item_path) as FoodItemData
	if food_data == null:
		_push_message("探索イベントが発生しましたが、食材データを読み込めませんでした。")
		return

	var base_amount: int = _get_random_gathering_amount(table)
	var level_bonus_amount: int = _get_gathering_amount_bonus(gathering_level)
	var upgrade_bonus_amount: int = _get_gathering_amount_plus_bonus()
	var amount: int = maxi(base_amount + level_bonus_amount + upgrade_bonus_amount, 1)
	var added: bool = false
	if inventory.has_method("add_food_item"):
		added = inventory.call("add_food_item", food_data, amount) == true
	elif inventory.has_method("add_item"):
		added = inventory.call(
			"add_item",
			food_data.category_id,
			food_data.item_id,
			food_data.display_name,
			amount,
			food_data.get_icon_path(),
			food_data.stack_max,
			food_data.description,
			food_data.buy_price,
			food_data.sell_price,
			food_data.get_need_effect_path(),
			food_data.can_discard,
			food_data.can_transfer
		) == true

	if added:
		_play_gathering_effect(food_data, amount)
		_add_gathering_experience()
		var bonus_text: String = ""
		if level_bonus_amount > 0:
			bonus_text += " / 採取Lv%dボーナス +%d" % [gathering_level, level_bonus_amount]
		if upgrade_bonus_amount > 0:
			bonus_text += " / 採取量＋1 Lv%d発動 +%d" % [_get_gathering_amount_plus_level(), upgrade_bonus_amount]
		_push_message("探索イベント: %s x%d を見つけました。採取EXP +%d%s" % [food_data.display_name, amount, maxi(gathering_experience_per_event, 0), bonus_text])
	else:
		_push_message("探索イベント: %s を見つけましたが、インベントリに空きがありません。" % food_data.display_name)


func _get_gathering_table() -> Resource:
	if _gathering_table != null:
		return _gathering_table
	if gathering_table_path.is_empty() or not ResourceLoader.exists(gathering_table_path):
		return null
	_gathering_table = load(gathering_table_path) as Resource
	return _gathering_table


func _is_gathering_table_empty(table: Resource, skill_level: int) -> bool:
	if table == null:
		return true
	if table.has_method("is_empty_for_skill"):
		return table.call("is_empty_for_skill", skill_level) == true
	if table.has_method("is_empty"):
		return table.call("is_empty") == true
	var item_paths_value: Variant = table.get("item_paths")
	if item_paths_value is PackedStringArray:
		return item_paths_value.is_empty()
	if item_paths_value is Array:
		return item_paths_value.is_empty()
	return true


func _get_random_gathering_item_path(table: Resource, skill_level: int) -> String:
	if table == null:
		return ""
	if table.has_method("get_random_item_path_for_skill"):
		return String(table.call("get_random_item_path_for_skill", _rng, skill_level))
	if table.has_method("get_random_item_path"):
		return String(table.call("get_random_item_path", _rng))
	var item_paths_value: Variant = table.get("item_paths")
	var required_levels_value: Variant = table.get("required_skill_levels")
	var available_paths: Array[String] = []
	if item_paths_value is PackedStringArray:
		var packed_paths: PackedStringArray = item_paths_value
		for index in range(packed_paths.size()):
			var required_level: int = _get_required_level_from_value(required_levels_value, index)
			if skill_level >= required_level:
				available_paths.append(String(packed_paths[index]))
	elif item_paths_value is Array:
		var paths: Array = item_paths_value
		for index in range(paths.size()):
			var required_level: int = _get_required_level_from_value(required_levels_value, index)
			if skill_level >= required_level:
				available_paths.append(String(paths[index]))
	if available_paths.is_empty():
		return ""
	return available_paths[_rng.randi_range(0, available_paths.size() - 1)]


func _get_required_level_from_value(required_levels_value: Variant, index: int) -> int:
	if required_levels_value is PackedInt32Array:
		var packed_levels: PackedInt32Array = required_levels_value
		if index >= 0 and index < packed_levels.size():
			return maxi(packed_levels[index], 1)
	if required_levels_value is Array:
		var levels: Array = required_levels_value
		if index >= 0 and index < levels.size():
			return maxi(int(levels[index]), 1)
	return 1


func _get_random_gathering_amount(table: Resource) -> int:
	if table != null and table.has_method("get_random_amount"):
		return int(table.call("get_random_amount", _rng))
	if table == null:
		return 1
	var amount_min_value: Variant = table.get("amount_min")
	var amount_max_value: Variant = table.get("amount_max")
	var safe_min: int = maxi(int(amount_min_value), 1)
	var safe_max: int = maxi(int(amount_max_value), safe_min)
	return _rng.randi_range(safe_min, safe_max)


func _get_gathering_level() -> int:
	var skills_module: Node = _get_skills_module()
	if skills_module == null or not skills_module.has_method("get_skill_level"):
		return 1
	return maxi(int(skills_module.call("get_skill_level", SKILL_GATHERING)), 1)


func _get_gathering_amount_bonus(skill_level: int) -> int:
	var safe_step: int = maxi(gathering_amount_bonus_level_step, 1)
	var raw_bonus: int = floori(float(skill_level) / float(safe_step))
	return clampi(raw_bonus, 0, maxi(gathering_amount_bonus_max, 0))


func _get_gathering_amount_plus_level() -> int:
	var skills_module: Node = _get_skills_module()
	if skills_module == null:
		return 0
	if skills_module.has_method("get_skill_upgrade_level"):
		return maxi(int(skills_module.call("get_skill_upgrade_level", SKILL_UPGRADE_GATHERING_AMOUNT_PLUS)), 0)
	if skills_module.has_method("get_gathering_amount_plus_level"):
		return maxi(int(skills_module.call("get_gathering_amount_plus_level")), 0)
	return 0


func _get_gathering_amount_plus_bonus() -> int:
	var upgrade_level: int = clampi(_get_gathering_amount_plus_level(), 0, 10)
	if upgrade_level <= 0:
		return 0
	var chance: float = clampf(float(upgrade_level) * 0.10, 0.0, 1.0)
	return 1 if _rng.randf() < chance else 0


func _add_gathering_experience() -> void:
	if gathering_experience_per_event <= 0:
		return
	var skills_module: Node = _get_skills_module()
	if skills_module == null or not skills_module.has_method("add_skill_experience"):
		return
	skills_module.call("add_skill_experience", SKILL_GATHERING, gathering_experience_per_event)


func _play_gathering_effect(food_data: FoodItemData, amount: int) -> void:
	if food_data == null:
		return
	var effect_module: Node = _ensure_gathering_effect_module()
	if effect_module == null or not effect_module.has_method("play_gathering_item_effect"):
		return
	effect_module.call(
		"play_gathering_item_effect",
		food_data.get_icon_path(),
		food_data.display_name,
		amount,
		_get_gathering_effect_source_position()
	)


func _get_gathering_effect_source_position() -> Vector2:
	var worker := _get_worker() as Node2D
	if worker != null and is_instance_valid(worker):
		return worker.global_position + gathering_effect_source_offset
	var background := _get_location_background()
	if background != null and background.has_method("get_panel_global_rect"):
		var panel_rect_value: Variant = background.call("get_panel_global_rect")
		if panel_rect_value is Rect2:
			var panel_rect: Rect2 = panel_rect_value
			return panel_rect.get_center()
	return Vector2.ZERO


func _configure_worker_presentation_for_exploration() -> void:
	var behavior: Node = _get_worker_entrance_behavior()
	if behavior == null:
		return
	if _has_property(behavior, &"work_fast_forward_scale"):
		if not _has_previous_work_fast_forward_scale:
			_previous_work_fast_forward_scale = float(behavior.get("work_fast_forward_scale"))
			_has_previous_work_fast_forward_scale = true
		var next_scale: float = exploration_time_scale if enable_time_acceleration else 1.0
		behavior.set("work_fast_forward_scale", maxf(next_scale, 1.0))
	if _has_property(behavior, &"work_location_body_position_ratio"):
		if not _has_previous_work_location_body_position_ratio:
			_previous_work_location_body_position_ratio = behavior.get("work_location_body_position_ratio") as Vector2
			_has_previous_work_location_body_position_ratio = true
		behavior.set("work_location_body_position_ratio", exploration_body_position_ratio)


func _restore_worker_presentation_after_exploration() -> void:
	var behavior: Node = _get_worker_entrance_behavior()
	if _has_previous_work_fast_forward_scale:
		if behavior != null and _has_property(behavior, &"work_fast_forward_scale"):
			behavior.set("work_fast_forward_scale", _previous_work_fast_forward_scale)
		_has_previous_work_fast_forward_scale = false
		_previous_work_fast_forward_scale = 8.0
	if _has_previous_work_location_body_position_ratio:
		if behavior != null and _has_property(behavior, &"work_location_body_position_ratio"):
			behavior.set("work_location_body_position_ratio", _previous_work_location_body_position_ratio)
		_has_previous_work_location_body_position_ratio = false
		_previous_work_location_body_position_ratio = Vector2(0.44, 0.58)


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


func _get_skills_module() -> Node:
	if _skills_module != null and is_instance_valid(_skills_module):
		return _skills_module
	_resolve_refs()
	var worker: Node = _get_worker()
	if _skills_module == null and worker != null and worker.has_method("get_skills_module"):
		_skills_module = worker.call("get_skills_module") as Node
	if _skills_module == null and worker != null:
		_skills_module = worker.get_node_or_null("AICharacterSkillsModule")
	return _skills_module


func _ensure_gathering_effect_module() -> Node:
	if _gathering_effect_module != null and is_instance_valid(_gathering_effect_module):
		return _gathering_effect_module
	_resolve_refs()
	if _gathering_effect_module != null and is_instance_valid(_gathering_effect_module):
		return _gathering_effect_module
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var existing_module := scene_root.get_node_or_null("ExplorationGatheringEffectModule")
		if existing_module != null:
			_gathering_effect_module = existing_module
			return _gathering_effect_module
	var effect_script := load(GATHERING_EFFECT_MODULE_SCRIPT_PATH) as Script
	if effect_script == null:
		return null
	var effect_module := effect_script.new() as Node
	if effect_module == null:
		return null
	effect_module.name = "ExplorationGatheringEffectModule"
	if scene_root != null:
		scene_root.add_child(effect_module)
	else:
		add_child(effect_module)
	_gathering_effect_module = effect_module
	return _gathering_effect_module


func _get_worker_display_name() -> String:
	var worker: Node = _get_worker()
	if worker == null:
		return "ロビン"
	var value: Variant = worker.get("display_name")
	var worker_name: String = String(value)
	if worker_name.is_empty():
		return "ロビン"
	return worker_name


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
	if _skills_module == null and not skills_module_path.is_empty():
		_skills_module = get_node_or_null(skills_module_path)
	if _location_background == null and not location_background_path.is_empty():
		_location_background = get_node_or_null(location_background_path)
	if _stay_overlay == null and not stay_overlay_path.is_empty():
		_stay_overlay = get_node_or_null(stay_overlay_path)
	if _gathering_effect_module == null and not gathering_effect_module_path.is_empty():
		_gathering_effect_module = get_node_or_null(gathering_effect_module_path)


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
	if message_log.has_method("add_exploration_message"):
		message_log.add_exploration_message(message)
		return
	message_log.add_message(message)
