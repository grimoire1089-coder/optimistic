extends Button
class_name BookButton

const DEFAULT_CLICK_SFX_PATH := "res://Assets/Audio/SFX/UI/UI_Click_001.ogg"
const DEFAULT_BOOK_ICON_PATH := "res://Assets/UI/Icons/Chip_Books_small.png"

@export var book_library_ui_path: NodePath = NodePath("../BookLibraryUI")
@export var fallback_group_name: StringName = &"book_library_ui"
@export var click_sfx: AudioStream
@export var click_sfx_volume_db: float = 0.0
@export var book_icon: Texture2D


func _ready() -> void:
	_apply_square_button_layout()
	_load_default_book_icon_if_needed()
	if icon != null:
		HudButtonStyle.apply_icon_button_layout(self)
		text = ""
	elif text.is_empty():
		text = "書籍"
	_load_default_click_sfx_if_needed()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play_click_sfx()
	var book_ui := _find_book_library_ui()
	if book_ui == null:
		push_warning("Book library UI not found: %s" % book_library_ui_path)
		return

	if book_ui.has_method("toggle_library"):
		book_ui.call("toggle_library")
		return
	if book_ui.has_method("toggle"):
		book_ui.call("toggle")
		return
	if book_ui.has_method("open"):
		book_ui.call("open")
		return
	if book_ui is CanvasItem:
		var canvas_item := book_ui as CanvasItem
		canvas_item.visible = not canvas_item.visible


func _find_book_library_ui() -> Node:
	var book_ui := get_node_or_null(book_library_ui_path)
	if book_ui != null:
		return book_ui
	return get_tree().get_first_node_in_group(fallback_group_name)


func _play_click_sfx() -> void:
	if click_sfx == null:
		return
	AudioPlayer.play_sfx(click_sfx, 1.0, click_sfx_volume_db)


func _load_default_click_sfx_if_needed() -> void:
	if click_sfx != null:
		return
	if ResourceLoader.exists(DEFAULT_CLICK_SFX_PATH):
		click_sfx = load(DEFAULT_CLICK_SFX_PATH) as AudioStream


func _load_default_book_icon_if_needed() -> void:
	if book_icon == null and icon != null:
		book_icon = icon
	if book_icon == null and ResourceLoader.exists(DEFAULT_BOOK_ICON_PATH):
		book_icon = load(DEFAULT_BOOK_ICON_PATH) as Texture2D
	if book_icon != null:
		icon = book_icon


func _apply_square_button_layout() -> void:
	HudButtonStyle.apply_square_button_layout(
		self,
		HudButtonStyle.first_row_offset(HudButtonStyle.FIRST_ROW_BOOK_LEFT)
	)


func _add_rounded_button_styles() -> void:
	HudButtonStyle.apply_rounded_button_styles(self)
