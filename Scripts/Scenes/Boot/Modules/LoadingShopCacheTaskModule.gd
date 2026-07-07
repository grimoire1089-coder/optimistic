extends "res://Scripts/Scenes/Boot/Modules/LoadingTaskModule.gd"
class_name LoadingShopCacheTaskModule


func _ready() -> void:
	task_id = &"shop_cache"
	display_name = "ショップデータ準備中..."
	weight = 1.0


func run_task(_context: Dictionary = {}) -> void:
	ShopRuntimeCache.prepare_default_database()
