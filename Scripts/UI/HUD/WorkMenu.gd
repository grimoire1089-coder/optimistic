extends PanelContainer
class_name WorkMenu

@export var first_job_name: String = "仕事001"
@export var first_job_minutes: int = 8 * 60

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var job_001_button: Button = $MarginContainer/Rows/JobList/Job001Button
@onready var detail_label: Label = $MarginContainer/Rows/DetailLabel


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_menu)
	job_001_button.pressed.connect(_on_job_001_pressed)
	_refresh()


func open_menu() -> void:
	visible = true
	_refresh()


func close_menu() -> void:
	visible = false


func _refresh() -> void:
	title_label.text = "仕事"
	job_001_button.text = "%s\n8時間" % first_job_name
	detail_label.text = "%s: ゲーム内時間を8時間進めます。" % first_job_name


func _on_job_001_pressed() -> void:
	GameClock.advance_minutes(first_job_minutes)
	close_menu()
