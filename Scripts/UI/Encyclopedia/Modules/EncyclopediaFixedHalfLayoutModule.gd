extends Node

const GROUP_NAME := &"encyclopedia_overlay"
const PAGE_CONFIGS := [
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/ToolPage"), "page_name": "ToolPage"},
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/FoodPage"), "page_name": "FoodPage"},
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/DrinkPage"), "page_name": "DrinkPage"},
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/IngredientPage"), "page_name": "IngredientPage"},
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/MaterialPage"), "page_name": "MaterialPage"},
	{"page_path": NodePath("ScreenMargin/MainPanel/MainMargin/RootRows/CategoryTabs/MiscPage"), "page_name": "MiscPage"},
]
const LEFT_NAMES := ["ListPanel", "FoodListPanel"]
const RIGHT_NAMES := ["DetailPanel", "FoodDetailPanel"]
const GAP := 6.0
const RETRY_SECONDS := 0.15
const MAX_RETRY_COUNT := 40

var _overlay: Control
var _pages: Array[Control] = []
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
	_pages.clear()

	for config in PAGE_CONFIGS:
		var page_path: NodePath = config.get("page_path", NodePath(""))
		var page_name := String(config.get("page_name", ""))
		var page_node := _overlay.get_node_or_null(page_path)
		if page_node == null:
			continue
		if page_node is HSplitContainer:
			page_node = _make_fixed_page(page_node as HSplitContainer, page_name)
		if page_node is Control:
			_pages.append(page_node as Control)

	if _pages.is_empty():
		_schedule_setup_retry()
		return

	_setup_done = true
	_connect_layout_signals()
	_apply()


func _connect_layout_signals() -> void:
	for page in _pages:
		if page != null and is_instance_valid(page) and not page.resized.is_connected(_apply):
			page.resized.connect(_apply)
	if _overlay != null and not _overlay.visibility_changed.is_connected(_apply):
		_overlay.visibility_changed.connect(_apply)


func _make_fixed_page(old_page: HSplitContainer, page_name: String) -> Control:
	var parent := old_page.get_parent()
	if parent == null:
		return old_page

	var index := old_page.get_index()
	var tab_title := ""
	var tab_container := parent as TabContainer
	var was_blocking_signals := false
	if tab_container != null:
		was_blocking_signals = tab_container.is_blocking_signals()
		if index >= 0 and index < tab_container.get_tab_count():
			tab_title = tab_container.get_tab_title(index)

	var left := _find_child_by_names(old_page, LEFT_NAMES)
	var right := _find_child_by_names(old_page, RIGHT_NAMES)
	if left == null or right == null:
		return old_page

	if tab_container != null:
		tab_container.set_block_signals(true)

	old_page.remove_child(left)
	old_page.remove_child(right)
	parent.remove_child(old_page)

	var fixed := Control.new()
	fixed.name = page_name
	fixed.set("layout_mode", 2)
	fixed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(fixed)
	parent.move_child(fixed, index)
	fixed.add_child(left)
	fixed.add_child(right)
	if tab_container != null and not tab_title.is_empty():
		tab_container.set_tab_title(index, tab_title)
	if tab_container != null:
		tab_container.set_block_signals(was_blocking_signals)
	old_page.queue_free()
	return fixed


func _apply() -> void:
	for page in _pages:
		if page == null or not is_instance_valid(page):
			continue
		var left := _find_child_by_names(page, LEFT_NAMES)
		var right := _find_child_by_names(page, RIGHT_NAMES)
		if left == null or right == null:
			continue
		_set_half(left, 0.0, 0.5, 0.0, -GAP)
		_set_half(right, 0.5, 1.0, GAP, 0.0)


func _find_child_by_names(parent: Node, names: Array) -> Control:
	if parent == null:
		return null
	for raw_name in names:
		var child := parent.get_node_or_null(NodePath(String(raw_name))) as Control
		if child != null:
			return child
	return null


func _set_half(node: Control, anchor_l: float, anchor_r: float, offset_l: float, offset_r: float) -> void:
	node.set("layout_mode", 1)
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
