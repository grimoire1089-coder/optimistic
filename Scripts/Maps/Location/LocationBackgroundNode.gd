extends Node2D
class_name LocationBackgroundNode

const DEFAULT_LOCATION_TEXTURE_PATH := "res://Assets/Maps/Location/Location_001.png"

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var texture_path: String = DEFAULT_LOCATION_TEXTURE_PATH
@export var show_background: bool = true
@export var width_ratio_to_map: float = 1.0
@export var height_ratio_to_width: float = 0.24
@export var min_height: float = 96.0
@export var max_height: float = 180.0
@export var bottom_gap: float = 14.0
@export var viewport_bottom_margin: float = 20.0
@export var fallback_color: Color = Color(0.05, 0.07, 0.12, 0.92)
@export var fallback_border_color: Color = Color(0.0, 1.6, 2.0, 0.75)
@export var fallback_accent_color: Color = Color(2.2, 0.15, 2.2, 0.72)
@export var fallback_border_width: float = 2.0
@export var fallback_corner_radius: int = 18

var _room_map: RoomMapGridModule
var _texture: Texture2D
var _loaded_texture_path: String = ""
var _draw_rect := Rect2()


func _ready() -> void:
	z_as_relative = false
	_load_texture_if_needed()
	_resolve_refs()
	_sync_layout()
	queue_redraw()


func _process(_delta: float) -> void:
	_resolve_refs()
	_sync_layout()
	queue_redraw()


func set_room_map_path(next_room_map_path: NodePath) -> void:
	if room_map_path == next_room_map_path:
		_resolve_refs()
		return
	room_map_path = next_room_map_path
	_room_map = null
	_resolve_refs()
	_sync_layout()
	queue_redraw()


func set_texture_path(next_texture_path: String) -> void:
	if texture_path == next_texture_path:
		return
	texture_path = next_texture_path
	_texture = null
	_loaded_texture_path = ""
	_load_texture_if_needed()
	queue_redraw()


func _draw() -> void:
	if not visible or _draw_rect.size.x <= 0.0 or _draw_rect.size.y <= 0.0:
		return
	if _texture != null:
		draw_texture_rect(_texture, _draw_rect, false, Color.WHITE)
		return
	_draw_fallback_background()


func _sync_layout() -> void:
	visible = show_background and _room_map != null and _room_map.visible
	if not visible:
		_draw_rect = Rect2()
		return
	if not _room_map.has_method("get_grid_rect"):
		_draw_rect = Rect2()
		return

	var grid_rect: Rect2 = _room_map.get_grid_rect()
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		_draw_rect = Rect2()
		return

	var target_width := grid_rect.size.x * clampf(width_ratio_to_map, 0.1, 1.4)
	var target_height := clampf(target_width * maxf(height_ratio_to_width, 0.01), min_height, max_height)
	var target_top := grid_rect.end.y + maxf(bottom_gap, 0.0)
	var viewport_rect := get_viewport().get_visible_rect()
	var bottom_limit := viewport_rect.end.y - maxf(viewport_bottom_margin, 0.0)
	if target_top + target_height > bottom_limit:
		target_top = bottom_limit - target_height
	if target_top < grid_rect.end.y + 2.0:
		target_top = grid_rect.end.y + 2.0

	global_position = Vector2(grid_rect.position.x + grid_rect.size.x * 0.5, target_top + target_height * 0.5)
	_draw_rect = Rect2(Vector2(-target_width * 0.5, -target_height * 0.5), Vector2(target_width, target_height))


func _load_texture_if_needed() -> void:
	if _loaded_texture_path == texture_path:
		return
	_loaded_texture_path = texture_path
	_texture = null
	if texture_path.is_empty():
		return
	if not ResourceLoader.exists(texture_path):
		return
	_texture = load(texture_path) as Texture2D


func _draw_fallback_background() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = fallback_color
	panel_style.border_color = fallback_border_color
	panel_style.set_border_width_all(roundi(maxf(fallback_border_width, 0.0)))
	panel_style.set_corner_radius_all(maxi(fallback_corner_radius, 0))
	draw_style_box(panel_style, _draw_rect)

	var accent_y := _draw_rect.position.y + _draw_rect.size.y * 0.72
	draw_line(Vector2(_draw_rect.position.x + 28.0, accent_y), Vector2(_draw_rect.end.x - 28.0, accent_y), fallback_accent_color, 2.0)
	draw_line(Vector2(_draw_rect.position.x + 56.0, accent_y + 14.0), Vector2(_draw_rect.end.x - 56.0, accent_y + 14.0), fallback_border_color, 2.0)


func _resolve_refs() -> void:
	if _room_map != null:
		return
	if room_map_path.is_empty():
		return
	_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
