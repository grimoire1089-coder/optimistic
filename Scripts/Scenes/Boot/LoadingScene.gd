extends Control

@onready var loading_label: Label = $CenterContainer/CenterBox/LoadingLabel
@onready var progress_bar: ProgressBar = $CenterContainer/CenterBox/ProgressBar
@onready var status_label: Label = $CenterContainer/CenterBox/StatusLabel

var _target_scene_path: String = ""
var _is_finished: bool = false


func _ready() -> void:
	loading_label.text = "LOADING"
	status_label.text = "準備中..."

	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0

	_target_scene_path = SceneRouter.get_loading_target_path()

	if _target_scene_path.is_empty():
		_show_error_and_return_title("ロード対象が指定されていません。")
		return

	var err := ResourceLoader.load_threaded_request(_target_scene_path)

	if err != OK:
		_show_error_and_return_title("ロード要求に失敗しました: %s" % _target_scene_path)
		return


func _process(_delta: float) -> void:
	if _is_finished:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)

	if progress.size() > 0:
		progress_bar.value = clampf(progress[0] * 100.0, 0.0, 100.0)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			status_label.text = "読み込み中..."

		ResourceLoader.THREAD_LOAD_LOADED:
			_is_finished = true
			progress_bar.value = 100.0
			status_label.text = "起動中..."

			await get_tree().process_frame

			var packed_scene := ResourceLoader.load_threaded_get(_target_scene_path) as PackedScene
			SceneRouter.clear_loading_target_path()
			SceneRouter.change_to_loaded_scene(packed_scene)

		ResourceLoader.THREAD_LOAD_FAILED:
			_is_finished = true
			_show_error_and_return_title("読み込みに失敗しました: %s" % _target_scene_path)

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_finished = true
			_show_error_and_return_title("無効なロード対象です: %s" % _target_scene_path)


func _show_error_and_return_title(message: String) -> void:
	push_error(message)

	loading_label.text = "ERROR"
	status_label.text = message
	progress_bar.value = 0.0

	await get_tree().create_timer(1.0).timeout
	SceneRouter.go_to_title()
