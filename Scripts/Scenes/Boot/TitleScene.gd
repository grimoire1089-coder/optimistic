extends Control

@onready var start_button: Button = $CenterContainer/CenterBox/StartButton
@onready var exit_button: Button = $CenterContainer/CenterBox/ExitButton


func _ready() -> void:
	start_button.text = "はじめる"
	exit_button.text = "おわる"

	start_button.pressed.connect(_on_start_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	exit_button.disabled = true

	SceneRouter.go_to_main()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
