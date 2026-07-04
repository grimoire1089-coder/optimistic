extends Control

@export var title_bgm: AudioStream
@export var start_button_sfx: AudioStream
@export var exit_button_sfx: AudioStream
@export var auto_fullscreen_on_matching_monitor: bool = true
@export var fullscreen_monitor_size: Vector2i = Vector2i(1920, 1080)
@export var allow_same_aspect_fullscreen: bool = true
@export var apply_fullscreen_in_editor: bool = true

@onready var start_button: Button = $CenterContainer/CenterBox/StartButton
@onready var options_button: Button = $CenterContainer/CenterBox/OptionsButton
@onready var exit_button: Button = $CenterContainer/CenterBox/ExitButton
@onready var audio_settings_layer: CanvasLayer = $AudioSettingsLayer
@onready var close_options_button: Button = $AudioSettingsLayer/CenterContainer/OverlayBox/CloseOptionsButton


func _enter_tree() -> void:
	_apply_startup_display_mode()


func _ready() -> void:
	call_deferred("_apply_startup_display_mode")

	start_button.text = "はじめる"
	options_button.text = "設定"
	exit_button.text = "おわる"
	audio_settings_layer.visible = false

	start_button.pressed.connect(_on_start_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	close_options_button.pressed.connect(_on_close_options_button_pressed)

	if title_bgm != null:
		AudioPlayer.play_bgm(title_bgm)


func _unhandled_input(event: InputEvent) -> void:
	if not audio_settings_layer.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_options()
		get_viewport().set_input_as_handled()


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	options_button.disabled = true
	exit_button.disabled = true

	if start_button_sfx != null:
		AudioPlayer.play_sfx(start_button_sfx)

	var game_clock := get_node_or_null("/root/GameClock") as GameClockSystem
	if game_clock != null:
		game_clock.reset_time()
		game_clock.start()

	var basic_income := get_node_or_null("/root/BasicIncome")
	if basic_income != null and basic_income.has_method("reset_for_new_game"):
		basic_income.call("reset_for_new_game")

	var bill_system := get_node_or_null("/root/BillSystem")
	if bill_system != null and bill_system.has_method("reset_for_new_game"):
		bill_system.call("reset_for_new_game")

	var work_rank_system := get_node_or_null("/root/WorkRankSystem")
	if work_rank_system != null and work_rank_system.has_method("reset_for_new_game"):
		work_rank_system.call("reset_for_new_game")

	SceneRouter.go_to_main()


func _on_options_button_pressed() -> void:
	audio_settings_layer.visible = true


func _on_close_options_button_pressed() -> void:
	_close_options()


func _on_exit_button_pressed() -> void:
	if exit_button_sfx != null:
		AudioPlayer.play_sfx(exit_button_sfx)

	get_tree().quit()


func _close_options() -> void:
	audio_settings_layer.visible = false


func _apply_startup_display_mode() -> void:
	if not auto_fullscreen_on_matching_monitor:
		return
	if OS.has_feature("editor") and not apply_fullscreen_in_editor:
		return

	var screen_index := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	if not _should_start_fullscreen_for_screen(screen_size):
		return

	DisplayServer.window_set_size(screen_size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _should_start_fullscreen_for_screen(screen_size: Vector2i) -> bool:
	if fullscreen_monitor_size.x <= 0 or fullscreen_monitor_size.y <= 0:
		return true
	if screen_size == fullscreen_monitor_size:
		return true
	if not allow_same_aspect_fullscreen:
		return false
	if screen_size.x <= 0 or screen_size.y <= 0:
		return false

	var target_aspect := float(fullscreen_monitor_size.x) / float(fullscreen_monitor_size.y)
	var screen_aspect := float(screen_size.x) / float(screen_size.y)
	return absf(screen_aspect - target_aspect) <= 0.02
