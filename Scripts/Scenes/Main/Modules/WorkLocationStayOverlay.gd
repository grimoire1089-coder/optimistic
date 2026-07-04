extends Node2D
class_name WorkLocationStayOverlay

const DEFAULT_WORKER_STANDING_TEXTURE_PATH := "res://Assets/Characters/Robin/Walk/robin_8dir_standing.png"
const DEFAULT_PARTNER_PORTRAIT_TEXTURE_PATH := "res://Assets/Characters/Gantetsu/Portraits/Gantetsu_Game_001.png"
const DEFAULT_PARTNER_STANDING_TEXTURE_PATH := "res://Assets/Characters/Gantetsu/Walk/Gantetsu_8dir_standing.png"
const ACTIVITY_KIND_WORK: StringName = &"work"
const ACTIVITY_KIND_EXPLORATION: StringName = &"exploration"

@export var location_background_path: NodePath = NodePath("../LocationBackground")
@export var worker_path: NodePath = NodePath("../Robin")
@export var worker_fallback_texture_path: String = DEFAULT_WORKER_STANDING_TEXTURE_PATH
@export var show_worker_duplicate: bool = false
@export var worker_duplicate_facing_direction: Vector2 = Vector2(1.0, 1.0)
@export var partner_display_name: String = "ガンテツ"
@export var partner_portrait_texture_path: String = DEFAULT_PARTNER_PORTRAIT_TEXTURE_PATH
@export var partner_standing_texture_path: String = DEFAULT_PARTNER_STANDING_TEXTURE_PATH
@export var partner_facing_direction: Vector2 = Vector2(-1.0, 1.0)
@export var worker_position_ratio: Vector2 = Vector2(0.44, 0.58)
@export var exploration_worker_position_ratio: Vector2 = Vector2(0.50, 0.48)
@export var partner_position_ratio: Vector2 = Vector2(0.58, 0.58)
@export var portrait_position_ratio: Vector2 = Vector2(0.16, 0.50)
@export var standing_target_height_ratio: float = 0.82
@export var standing_target_max_height: float = 132.0
@export var exploration_standing_target_height_ratio: float = 0.68
@export var exploration_standing_target_max_height: float = 116.0
@export var portrait_target_height_ratio: float = 0.62
@export var portrait_target_max_height: float = 98.0
@export var status_card_width_ratio_to_map: float = 0.66
@export var status_card_max_width: float = 520.0
@export var status_card_height: float = 44.0
@export var hud_top_margin: float = 12.0
@export var hud_left_margin: float = 12.0
@export var hud_gap: float = 8.0
@export var progress_width_ratio_to_map: float = 0.48
@export var progress_max_width: float = 360.0
@export var progress_height: float = 8.0
@export var status_text_color: Color = Color(0.88, 0.98, 1.0, 1.0)
@export var status_shadow_color: Color = Color(0.0, 0.72, 1.0, 0.6)
@export var status_card_color: Color = Color(0.01, 0.02, 0.035, 0.76)
@export var status_card_border_color: Color = Color(0.0, 1.5, 1.8, 0.74)
@export var progress_background_color: Color = Color(0.0, 0.0, 0.0, 0.56)
@export var progress_fill_color: Color = Color(0.16, 0.88, 1.0, 0.92)
@export var progress_border_color: Color = Color(0.0, 1.4, 1.8, 0.8)

var _location_background: Node
var _worker: Node
var _worker_sprite: Sprite2D
var _partner_sprite: Sprite2D
var _partner_portrait_sprite: Sprite2D
var _status_label: Label
var _partner_name_label: Label
var _active := false
var _activity_kind: StringName = ACTIVITY_KIND_WORK
var _job_id: StringName = &""
var _job_display_name := ""
var _worker_display_name := ""


func _ready() -> void:
	z_as_relative = false
	z_index = 40
	_ensure_children()
	_resolve_refs()
	hide_work_stay()
	set_process(true)


func show_work_stay(job_id: StringName, job_display_name: String = "", worker_display_name: String = "") -> void:
	_show_location_stay(ACTIVITY_KIND_WORK, job_id, job_display_name, worker_display_name)


func show_exploration_stay(location_id: StringName, location_display_name: String = "", worker_display_name: String = "") -> void:
	_show_location_stay(ACTIVITY_KIND_EXPLORATION, location_id, location_display_name, worker_display_name)


func hide_work_stay() -> void:
	_active = false
	visible = false
	_activity_kind = ACTIVITY_KIND_WORK
	_job_id = &""
	_job_display_name = ""
	_worker_display_name = ""
	queue_redraw()


func _show_location_stay(activity_kind: StringName, job_id: StringName, job_display_name: String = "", worker_display_name: String = "") -> void:
	_activity_kind = activity_kind
	_job_id = job_id
	_job_display_name = job_display_name
	_worker_display_name = worker_display_name
	_active = true
	visible = true
	_resolve_refs()
	_sync_worker_sprite_texture()
	_update_status_text()
	_sync_layout()
	queue_redraw()


func _process(_delta: float) -> void:
	if not _active:
		return
	_resolve_refs()
	if not _is_worker_activity_active():
		hide_work_stay()
		return
	_sync_worker_sprite_texture()
	_sync_layout()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var panel_rect := _get_panel_global_rect()
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return
	var status_card_rect := _get_status_card_global_rect(panel_rect)
	var progress_bar_rect := _get_progress_bar_global_rect(panel_rect, status_card_rect)
	_draw_status_card(Rect2(to_local(status_card_rect.position), status_card_rect.size))
	_draw_work_progress(Rect2(to_local(progress_bar_rect.position), progress_bar_rect.size))


func _ensure_children() -> void:
	if _worker_sprite == null:
		_worker_sprite = Sprite2D.new()
		_worker_sprite.name = "WorkerSprite"
		_worker_sprite.centered = true
		_worker_sprite.z_index = 3
		add_child(_worker_sprite)
	if _partner_sprite == null:
		_partner_sprite = Sprite2D.new()
		_partner_sprite.name = "PartnerSprite"
		_partner_sprite.centered = true
		_partner_sprite.z_index = 2
		add_child(_partner_sprite)
	if _partner_portrait_sprite == null:
		_partner_portrait_sprite = Sprite2D.new()
		_partner_portrait_sprite.name = "PartnerPortrait"
		_partner_portrait_sprite.centered = true
		_partner_portrait_sprite.z_index = 1
		add_child(_partner_portrait_sprite)
	if _status_label == null:
		_status_label = Label.new()
		_status_label.name = "StatusLabel"
		_status_label.z_index = 5
		_status_label.add_theme_color_override("font_color", status_text_color)
		_status_label.add_theme_color_override("font_shadow_color", status_shadow_color)
		_status_label.add_theme_constant_override("shadow_offset_x", 0)
		_status_label.add_theme_constant_override("shadow_offset_y", 1)
		_status_label.add_theme_font_size_override("font_size", 16)
		add_child(_status_label)
	if _partner_name_label == null:
		_partner_name_label = Label.new()
		_partner_name_label.name = "PartnerNameLabel"
		_partner_name_label.z_index = 5
		_partner_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_partner_name_label.add_theme_color_override("font_color", status_text_color)
		_partner_name_label.add_theme_color_override("font_shadow_color", status_shadow_color)
		_partner_name_label.add_theme_constant_override("shadow_offset_x", 0)
		_partner_name_label.add_theme_constant_override("shadow_offset_y", 1)
		_partner_name_label.add_theme_font_size_override("font_size", 14)
		add_child(_partner_name_label)

	_configure_direction_sprite(_partner_sprite, partner_standing_texture_path, partner_facing_direction)
	_configure_plain_sprite(_partner_portrait_sprite, partner_portrait_texture_path)


func _sync_layout() -> void:
	var panel_rect := _get_panel_global_rect()
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		_set_content_visible(false)
		return
	_set_content_visible(true)

	var worker_ratio := worker_position_ratio
	var worker_height_ratio := standing_target_height_ratio
	var worker_max_height := standing_target_max_height
	if _activity_kind == ACTIVITY_KIND_EXPLORATION:
		worker_ratio = exploration_worker_position_ratio
		worker_height_ratio = exploration_standing_target_height_ratio
		worker_max_height = exploration_standing_target_max_height
	var standing_target_height := minf(
		panel_rect.size.y * clampf(worker_height_ratio, 0.1, 2.0),
		maxf(worker_max_height, 1.0)
	)
	var partner_target_height := minf(
		panel_rect.size.y * clampf(standing_target_height_ratio, 0.1, 2.0),
		maxf(standing_target_max_height, 1.0)
	)
	var portrait_target_height := minf(
		panel_rect.size.y * clampf(portrait_target_height_ratio, 0.1, 2.0),
		maxf(portrait_target_max_height, 1.0)
	)

	_worker_sprite.global_position = _point_in_rect(panel_rect, worker_ratio)
	_partner_sprite.global_position = _point_in_rect(panel_rect, partner_position_ratio)
	_partner_portrait_sprite.global_position = _point_in_rect(panel_rect, portrait_position_ratio)
	_scale_sprite_to_height(_worker_sprite, standing_target_height)
	_scale_sprite_to_height(_partner_sprite, partner_target_height)
	_scale_sprite_to_height(_partner_portrait_sprite, portrait_target_height)

	var status_card_rect := _get_status_card_global_rect(panel_rect)
	_status_label.global_position = status_card_rect.position + Vector2(14.0, 10.0)
	_status_label.size = Vector2(maxf(status_card_rect.size.x - 28.0, 1.0), maxf(status_card_rect.size.y - 12.0, 1.0))
	_partner_name_label.global_position = _partner_portrait_sprite.global_position + Vector2(-70.0, portrait_target_height * 0.42)
	_partner_name_label.size = Vector2(140.0, 24.0)


func _set_content_visible(content_visible: bool) -> void:
	var show_partner := _activity_kind == ACTIVITY_KIND_WORK
	_worker_sprite.visible = content_visible and show_worker_duplicate
	_partner_sprite.visible = content_visible and show_partner
	_partner_portrait_sprite.visible = content_visible and show_partner
	_status_label.visible = content_visible
	_partner_name_label.visible = content_visible and show_partner


func _update_status_text() -> void:
	var activity_name := _job_display_name
	if activity_name.is_empty():
		activity_name = str(_job_id)
	if activity_name.is_empty():
		activity_name = "アルバイト"
	var worker_name := _worker_display_name
	if worker_name.is_empty():
		worker_name = "ロビン"
	if _activity_kind == ACTIVITY_KIND_EXPLORATION:
		_status_label.text = "%s / %s 探索中" % [activity_name, worker_name]
		_partner_name_label.text = ""
		return
	_status_label.text = "%s / %s -> %sさん" % [activity_name, worker_name, partner_display_name]
	_partner_name_label.text = partner_display_name


func _draw_status_card(card_rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = status_card_color
	style.border_color = status_card_border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(status_card_border_color.r, status_card_border_color.g, status_card_border_color.b, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	draw_style_box(style, card_rect)


func _draw_work_progress(bar_rect: Rect2) -> void:
	var progress := _get_work_progress_ratio()
	var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y))
	draw_rect(bar_rect, progress_background_color, true)
	draw_rect(fill_rect, progress_fill_color, true)
	draw_rect(bar_rect, progress_border_color, false, 1.0)


func _get_status_card_global_rect(panel_rect: Rect2) -> Rect2:
	var map_rect := _get_map_global_rect()
	var anchor_rect := map_rect if map_rect.size.x > 0.0 and map_rect.size.y > 0.0 else panel_rect
	var card_width := minf(anchor_rect.size.x * clampf(status_card_width_ratio_to_map, 0.1, 1.4), maxf(status_card_max_width, 1.0))
	var card_height := maxf(status_card_height, 1.0)
	var reserved_height := card_height + maxf(progress_height, 1.0) + maxf(hud_gap, 0.0) + maxf(hud_top_margin, 0.0)
	var card_position := Vector2(
		anchor_rect.position.x + maxf(hud_left_margin, 0.0),
		anchor_rect.position.y - reserved_height
	)
	if card_position.y < 8.0:
		card_position.y = 8.0
	return Rect2(card_position, Vector2(card_width, card_height))


func _get_progress_bar_global_rect(panel_rect: Rect2, status_card_rect: Rect2) -> Rect2:
	var map_rect := _get_map_global_rect()
	var anchor_rect := map_rect if map_rect.size.x > 0.0 and map_rect.size.y > 0.0 else panel_rect
	var bar_width := minf(anchor_rect.size.x * clampf(progress_width_ratio_to_map, 0.1, 1.4), maxf(progress_max_width, 1.0))
	var bar_height := maxf(progress_height, 1.0)
	var bar_position := Vector2(
		anchor_rect.position.x + (anchor_rect.size.x - bar_width) * 0.5,
		status_card_rect.end.y + maxf(hud_gap, 0.0)
	)
	return Rect2(bar_position, Vector2(bar_width, bar_height))


func _sync_worker_sprite_texture() -> void:
	var source_sprite := _get_source_worker_sprite()
	if source_sprite != null and source_sprite.texture != null:
		_worker_sprite.texture = source_sprite.texture
		_worker_sprite.hframes = maxi(source_sprite.hframes, 1)
		_worker_sprite.vframes = maxi(source_sprite.vframes, 1)
		_worker_sprite.frame = clampi(source_sprite.frame, 0, _worker_sprite.hframes * _worker_sprite.vframes - 1)
		_worker_sprite.flip_h = source_sprite.flip_h
		return
	_configure_direction_sprite(_worker_sprite, worker_fallback_texture_path, worker_duplicate_facing_direction)


func _configure_direction_sprite(sprite: Sprite2D, texture_path: String, facing_direction: Vector2) -> void:
	if sprite == null:
		return
	var texture := _load_texture(texture_path)
	sprite.texture = texture
	sprite.hframes = 2
	sprite.vframes = 4
	sprite.frame_coords = _direction_to_frame_coords(facing_direction)
	sprite.visible = texture != null


func _configure_plain_sprite(sprite: Sprite2D, texture_path: String) -> void:
	if sprite == null:
		return
	var texture := _load_texture(texture_path)
	sprite.texture = texture
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.visible = texture != null


func _scale_sprite_to_height(sprite: Sprite2D, target_height: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var frame_size := _get_sprite_frame_size(sprite)
	if frame_size.y <= 0.0:
		return
	var scale_value := maxf(target_height, 1.0) / frame_size.y
	sprite.scale = Vector2(scale_value, scale_value)


func _get_sprite_frame_size(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	var texture_size := sprite.texture.get_size()
	return Vector2(
		texture_size.x / float(maxi(sprite.hframes, 1)),
		texture_size.y / float(maxi(sprite.vframes, 1))
	)


func _get_source_worker_sprite() -> Sprite2D:
	_resolve_refs()
	if _worker == null:
		return null
	return _worker.get_node_or_null("Sprite2D") as Sprite2D


func _get_work_progress_ratio() -> float:
	var behavior := _get_worker_entrance_behavior()
	if behavior == null:
		return 0.0
	if not behavior.has_method("get_work_progress_ratio"):
		return 0.0
	return clampf(float(behavior.call("get_work_progress_ratio")), 0.0, 1.0)


func _is_worker_activity_active() -> bool:
	_resolve_refs()
	if _worker == null:
		return _active
	if not _worker.has_method("is_working"):
		return _active
	return _worker.call("is_working") == true


func _get_worker_entrance_behavior() -> Node:
	_resolve_refs()
	if _worker == null:
		return null
	return _worker.get_node_or_null("AICharacterEntranceTravelBehaviorModule")


func _get_panel_global_rect() -> Rect2:
	_resolve_refs()
	if _location_background == null:
		return Rect2()
	if _location_background.has_method("get_panel_global_rect"):
		var panel_rect_value: Variant = _location_background.call("get_panel_global_rect")
		if panel_rect_value is Rect2:
			var panel_rect: Rect2 = panel_rect_value
			return panel_rect
	return Rect2()


func _get_map_global_rect() -> Rect2:
	_resolve_refs()
	if _location_background == null:
		return Rect2()
	if not _location_background.has_method("get_room_map_global_rect"):
		return Rect2()
	var map_rect_value: Variant = _location_background.call("get_room_map_global_rect")
	if map_rect_value is Rect2:
		return map_rect_value
	return Rect2()


func _point_in_rect(rect: Rect2, ratio: Vector2) -> Vector2:
	return rect.position + Vector2(
		rect.size.x * clampf(ratio.x, 0.0, 1.0),
		rect.size.y * clampf(ratio.y, 0.0, 1.0)
	)


func _load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


func _direction_to_frame_coords(direction: Vector2) -> Vector2i:
	if direction.length_squared() <= 0.001:
		return Vector2i(0, 0)
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
		return Vector2i(0, 0)
	if x == 0 and y == -1:
		return Vector2i(1, 0)
	if x == 1 and y == 0:
		return Vector2i(0, 1)
	if x == -1 and y == 0:
		return Vector2i(1, 1)
	if x == 1 and y == 1:
		return Vector2i(0, 2)
	if x == -1 and y == 1:
		return Vector2i(1, 2)
	if x == 1 and y == -1:
		return Vector2i(0, 3)
	if x == -1 and y == -1:
		return Vector2i(1, 3)
	return Vector2i(0, 0)


func _resolve_refs() -> void:
	if _location_background == null and not location_background_path.is_empty():
		_location_background = get_node_or_null(location_background_path)
	if _worker == null and not worker_path.is_empty():
		_worker = get_node_or_null(worker_path)
