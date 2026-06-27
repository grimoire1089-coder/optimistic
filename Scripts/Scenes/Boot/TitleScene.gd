extends Control

@export var title_bgm: AudioStream
@export var start_button_sfx: AudioStream
@export var exit_button_sfx: AudioStream

@onready var start_button: Button = $CenterContainer/CenterBox/StartButton
@onready var exit_button: Button = $CenterContainer/CenterBox/ExitButton


func _ready() -> void:
	start_button.text = "はじめる"
	exit_button.text = "おわる"

	start_button.pressed.connect(_on_start_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	if title_bgm != null:
		AudioPlayer.play_bgm(title_bgm)


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	exit_button.disabled = true

	if start_button_sfx != null:
		AudioPlayer.play_sfx(start_button_sfx)

	SceneRouter.go_to_main()


func _on_exit_button_pressed() -> void:
	if exit_button_sfx != null:
		AudioPlayer.play_sfx(exit_button_sfx)

	get_tree().quit()
