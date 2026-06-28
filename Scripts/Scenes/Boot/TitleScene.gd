extends Control

@export var title_bgm: AudioStream
@export var start_button_sfx: AudioStream
@export var exit_button_sfx: AudioStream

@onready var start_button: Button = $CenterContainer/CenterBox/StartButton
@onready var options_button: Button = $CenterContainer/CenterBox/OptionsButton
@onready var exit_button: Button = $CenterContainer/CenterBox/ExitButton
@onready var audio_settings_layer: CanvasLayer = $AudioSettingsLayer
@onready var close_options_button: Button = $AudioSettingsLayer/CenterContainer/OverlayBox/CloseOptionsButton


func _ready() -> void:
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
