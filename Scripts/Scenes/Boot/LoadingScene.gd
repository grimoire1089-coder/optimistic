extends Control

const SCENE_LOAD_PROGRESS_MAX := 80.0
const TASK_PROGRESS_MIN := 80.0
const TASK_PROGRESS_MAX := 100.0

@onready var loading_label: Label = $CenterContainer/CenterBox/LoadingLabel
@onready var progress_bar: ProgressBar = $CenterContainer/CenterBox/ProgressBar
@onready var status_label: Label = $CenterContainer/CenterBox/StatusLabel
@onready var task_modules_root: Node = get_node_or_null("TaskModules")

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

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)

	if progress.size() > 0:
		progress_bar.value = clampf(progress[0] * SCENE_LOAD_PROGRESS_MAX, 0.0, SCENE_LOAD_PROGRESS_MAX)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			status_label.text = "読み込み中..."

		ResourceLoader.THREAD_LOAD_LOADED:
			_is_finished = true
			progress_bar.value = SCENE_LOAD_PROGRESS_MAX
			await _run_loading_tasks()

			status_label.text = "起動中..."
			progress_bar.value = TASK_PROGRESS_MAX
			var packed_scene := ResourceLoader.load_threaded_get(_target_scene_path) as PackedScene
			SceneRouter.clear_loading_target_path()
			SceneRouter.change_to_loaded_scene(packed_scene)

		ResourceLoader.THREAD_LOAD_FAILED:
			_is_finished = true
			_show_error_and_return_title("読み込みに失敗しました: %s" % _target_scene_path)

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_finished = true
			_show_error_and_return_title("無効なロード対象です: %s" % _target_scene_path)


func _run_loading_tasks() -> void:
	var tasks: Array[Node] = _get_enabled_loading_tasks()
	if tasks.is_empty():
		await get_tree().process_frame
		return

	var total_weight: float = _get_total_task_weight(tasks)
	var completed_weight: float = 0.0
	var context: Dictionary = {
		"target_scene_path": _target_scene_path,
	}

	for task in tasks:
		var task_name: String = _get_task_display_name(task)
		if not task_name.is_empty():
			status_label.text = task_name

		if task.has_method("run_task"):
			task.call("run_task", context)
		completed_weight += _get_task_weight(task)
		progress_bar.value = _get_task_progress_value(completed_weight, total_weight)
		await get_tree().process_frame


func _get_enabled_loading_tasks() -> Array[Node]:
	var result: Array[Node] = []
	if task_modules_root == null:
		return result

	for child in task_modules_root.get_children():
		if not (child is Node):
			continue
		var task := child as Node
		if not _is_task_enabled(task):
			continue
		result.append(task)

	return result


func _is_task_enabled(task: Node) -> bool:
	if task == null:
		return false
	if task.has_method("is_task_enabled"):
		return task.call("is_task_enabled") == true
	return false


func _get_task_display_name(task: Node) -> String:
	if task == null:
		return ""
	if task.has_method("get_task_display_name"):
		return String(task.call("get_task_display_name"))
	return ""


func _get_task_weight(task: Node) -> float:
	if task == null:
		return 0.0
	if task.has_method("get_task_weight"):
		return maxf(float(task.call("get_task_weight")), 0.0)
	return 0.0


func _get_total_task_weight(tasks: Array[Node]) -> float:
	var result := 0.0
	for task in tasks:
		result += _get_task_weight(task)
	return maxf(result, 0.001)


func _get_task_progress_value(completed_weight: float, total_weight: float) -> float:
	var safe_total := maxf(total_weight, 0.001)
	var ratio := clampf(completed_weight / safe_total, 0.0, 1.0)
	return lerpf(TASK_PROGRESS_MIN, TASK_PROGRESS_MAX, ratio)


func _show_error_and_return_title(message: String) -> void:
	push_error(message)

	loading_label.text = "ERROR"
	status_label.text = message
	progress_bar.value = 0.0

	await get_tree().create_timer(1.0).timeout
	SceneRouter.go_to_title()
