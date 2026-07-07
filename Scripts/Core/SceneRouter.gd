extends Node

const TITLE_SCENE_PATH := "res://Scenes/Boot/TitleScene.tscn"
const LOADING_SCENE_PATH := "res://Scenes/Boot/LoadingScene.tscn"
const MAIN_SCENE_PATH := "res://Scenes/Main/MainScene.tscn"

var _loading_target_path: String = ""
var _is_changing_scene: bool = false


func go_to_title() -> void:
	_loading_target_path = ""
	_change_scene_to_file_safe(TITLE_SCENE_PATH)


func go_to_main() -> void:
	ShopRuntimeCache.prepare_default_database()
	request_load(MAIN_SCENE_PATH)


func request_load(target_scene_path: String) -> void:
	if _is_changing_scene:
		return

	if target_scene_path.is_empty():
		push_error("ロード対象のシーンパスが空です。")
		return

	_loading_target_path = target_scene_path
	_change_scene_to_file_safe(LOADING_SCENE_PATH)


func get_loading_target_path() -> String:
	return _loading_target_path


func clear_loading_target_path() -> void:
	_loading_target_path = ""


func change_to_loaded_scene(packed_scene: PackedScene) -> void:
	if packed_scene == null:
		push_error("PackedSceneがnullです。")
		go_to_title()
		return

	_is_changing_scene = true
	var err := get_tree().change_scene_to_packed(packed_scene)
	_is_changing_scene = false

	if err != OK:
		push_error("シーン切り替えに失敗しました。Error: %s" % err)
		go_to_title()


func _change_scene_to_file_safe(scene_path: String) -> void:
	_is_changing_scene = true
	var err := get_tree().change_scene_to_file(scene_path)
	_is_changing_scene = false

	if err != OK:
		push_error("シーン切り替えに失敗しました: %s / Error: %s" % [scene_path, err])
