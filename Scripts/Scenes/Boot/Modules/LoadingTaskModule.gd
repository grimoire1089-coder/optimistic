extends Node
class_name LoadingTaskModule

@export var task_id: StringName = &""
@export var display_name: String = "準備中..."
@export_range(0.0, 100.0, 1.0) var weight: float = 1.0
@export var is_enabled: bool = true


func is_task_enabled() -> bool:
	return is_enabled


func get_task_display_name() -> String:
	return display_name


func get_task_weight() -> float:
	return maxf(weight, 0.0)


func run_task(_context: Dictionary = {}) -> void:
	pass
