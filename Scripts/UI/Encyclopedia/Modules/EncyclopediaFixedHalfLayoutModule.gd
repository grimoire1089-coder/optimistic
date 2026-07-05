extends Node

const GROUP_NAME := &"encyclopedia_overlay"
const FOOD_PAGE_PATH := NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage")
const LEFT_NAME := "FoodListPanel"
const RIGHT_NAME := "FoodDetailPanel"
const GAP := 6.0
const RETRY_SECONDS := 0.15
const MAX_RETRY_COUNT := 40

var _overlay: Control
var _page: Control
var _retry_count := 0
var _retry_scheduled := false
var _setup_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_schedule_setup_retry()


func _setup() -> void:
	_retry_scheduled = false
	if _setup_done:
		return

	var node := get_tree().get_first_node_in_group(GROUP_NAME)
	if not (node is Control):
		_schedule_setup_retry()
		return

	_overlay = node as Control
	var page_node := _overlay.get_node_or_null(FOOD_PAGE_PATH)
	if page_node == null:
		_schedule_setup_retry()
		return

	if page_node is HSplitContainer:
		page_node = _make_fixed_page(page_node as HSplitContainer)

	if not (page_node is Control):
		return

	_page = page_node as Control
	_setup_done = true
	_connect_layout_signals()
	_apply()


func _connect_layout_signals() -> void:
	if _page != null and not _page.resized.is_connected(_apply):
		_page.resized.connect(_apply)
	if _overlay != null and not _overlay.visibility_changed.is_connected(_apply):
		_overlay.visibility_changed.connect(_apply)


func _make_fixed_page(old_page: HSplitContainer) -> Control:
	var parent := old_page.get_parent()
	if parent == null:
		return old_page

	var index := old_page.get_index()
	var left := old_page.get_node_or_null(LEFT_NAME)
	var right := old_page.get_node_or_null(RIGHT_NAME)
	if left == null or right == null:
		return old_page

	old_page.remove_child(left)
	old_page.remove_child(right)
	parent.remove_child(old_page)

	var fixed := Control.new()
	fixed.name = "FoodPage"
	fixed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(fixed)
	parent.move_child(fixed, index)
	fixed.add_child(left)
	fixed.add_child(right)
	old_page.queue_free()
	return fixed


func _apply() -> void:
	if _page == null or not is_instance_valid(_page):
		return
	var left := _page.get_node_or_null(LEFT_NAME) as Control
	var right := _page.get_node_or_null(RIGHT_NAME) as Control
	if left == null or right == null:
		return
	_set_half(left, 0.0, 0.5, 0.0, -GAP)
	_set_half(right, 0.5, 1.0, GAP, 0.0)


func _set_half(node: Control, anchor_l: float, anchor_r: float, offset_l: float, offset_r: float) -> void:
	node.anchor_left = anchor_l
	node.anchor_top = 0.0
	node.anchor_right = anchor_r
	node.anchor_bottom = 1.0
	node.offset_left = offset_l
	node.offset_top = 0.0
	node.offset_right = offset_r
	node.offset_bottom = 0.0


func _schedule_setup_retry() -> void:
	if _retry_scheduled or _setup_done:
		return
	if _retry_count >= MAX_RETRY_COUNT:
		return
	_retry_scheduled = true
	_retry_count += 1
	_retry_setup_after_delay()


func _retry_setup_after_delay() -> void:
	await get_tree().create_timer(RETRY_SECONDS).timeout
	_setup()
