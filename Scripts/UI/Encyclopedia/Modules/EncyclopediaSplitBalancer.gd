extends Node

const ENCYCLOPEDIA_GROUP := &"encyclopedia_overlay"
const FOOD_PAGE_PATH := NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage")
const HALF_RATIO := 0.5
const RETRY_SECONDS := 0.05
const MAX_RETRY_COUNT := 30
const DRAGGER_HIDDEN_COLLAPSED := 2

var _overlay: Control
var _food_page_split: HSplitContainer
var _retry_count := 0
var _last_applied_width := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_refresh_overlay_refs")


func _process(_delta: float) -> void:
	if _food_page_split == null or not is_instance_valid(_food_page_split):
		_refresh_overlay_refs()
		return
	if _overlay == null or not is_instance_valid(_overlay) or not _overlay.visible:
		return
	_apply_half_split()


func _on_node_added(_node: Node) -> void:
	call_deferred("_refresh_overlay_refs")


func _refresh_overlay_refs() -> void:
	var overlay_node := get_tree().get_first_node_in_group(ENCYCLOPEDIA_GROUP)
	if not (overlay_node is Control):
		_retry_half_split()
		return

	_overlay = overlay_node as Control
	_food_page_split = _overlay.get_node_or_null(FOOD_PAGE_PATH) as HSplitContainer
	if _food_page_split == null:
		_retry_half_split()
		return

	_lock_split_dragger()
	_connect_layout_signals()
	_apply_half_split_deferred()


func _connect_layout_signals() -> void:
	if _overlay != null:
		if not _overlay.resized.is_connected(_apply_half_split_deferred):
			_overlay.resized.connect(_apply_half_split_deferred)
		if not _overlay.visibility_changed.is_connected(_apply_half_split_deferred):
			_overlay.visibility_changed.connect(_apply_half_split_deferred)
	if _food_page_split != null:
		if not _food_page_split.resized.is_connected(_apply_half_split_deferred):
			_food_page_split.resized.connect(_apply_half_split_deferred)


func _apply_half_split_deferred() -> void:
	call_deferred("_apply_half_split")


func _apply_half_split() -> void:
	if _food_page_split == null or not is_instance_valid(_food_page_split):
		_refresh_overlay_refs()
		return

	var width := _food_page_split.size.x
	if width <= 0.0:
		_retry_half_split()
		return

	_retry_count = 0
	_last_applied_width = width
	_lock_split_dragger()
	_food_page_split.split_offset = int(round(width * HALF_RATIO))


func _lock_split_dragger() -> void:
	if _food_page_split == null or not is_instance_valid(_food_page_split):
		return
	_food_page_split.set("dragger_visibility", DRAGGER_HIDDEN_COLLAPSED)


func _retry_half_split() -> void:
	if _retry_count >= MAX_RETRY_COUNT:
		return
	_retry_count += 1
	await get_tree().create_timer(RETRY_SECONDS).timeout
	_refresh_overlay_refs()
