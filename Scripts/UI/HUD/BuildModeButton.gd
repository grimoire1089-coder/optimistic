extends Button
class_name BuildModeButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"

@export var label_text: String = "ビルド"
@export var active_label_text: String = "ビルド中"
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0

var _room_map: RoomMapGridModule


func _ready() -> void:
	toggle_mode = true
	_load_default_click_sfx_if_needed()
	_resolve_room_map()
	_sync_button_state()
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	_sync_button_state()


func _on_pressed() -> void:
	_play_click_sfx()
	_resolve_room_map()
	if _room_map == null:
		button_pressed = false
		push_warning("Room map not found: %s" % room_map_path)
		return
	if not _room_map.is_buildable():
		button_pressed = false
		return

	_room_map.set_build_mode_enabled(button_pressed)
	_sync_button_state()


func _sync_button_state() -> void:
	_resolve_room_map()
	var can_build := _room_map != null and _room_map.is_buildable()
	disabled = not can_build

	if not can_build:
		button_pressed = false
		text = label_text
		tooltip_text = "この場所ではビルドできません"
		return

	if _room_map.is_build_mode_enabled():
		button_pressed = true
		text = active_label_text
		tooltip_text = "ビルドモード中"
	else:
		button_pressed = false
		text = label_text
		tooltip_text = "ビルドモードを開始"


func _resolve_room_map() -> void:
	if _room_map != null:
		return
	if room_map_path.is_empty():
		return
	_room_map = get_node_or_null(room_map_path) as RoomMapGridModule


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream
