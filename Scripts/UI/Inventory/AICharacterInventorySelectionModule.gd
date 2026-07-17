extends Node
class_name AICharacterInventorySelectionModule

const SELECTION_CONTEXT_GROUP: StringName = &"ai_character_selection_context"
const InventoryLookup := preload("res://Scripts/Characters/Modules/AICharacterInventoryLookup.gd")
const TITLE_LABEL_PATH := NodePath("MarginContainer/Rows/Header/TitleLabel")
const SEARCH_LINE_EDIT_PATH := NodePath("MarginContainer/Rows/Footer/SearchLineEdit")
const REFRESH_SIGNAL_TARGETS := [
	{"path": NodePath("MarginContainer/Rows/Header/PreviousPageButton"), "signal": &"pressed"},
	{"path": NodePath("MarginContainer/Rows/Header/NextPageButton"), "signal": &"pressed"},
	{"path": NodePath("MarginContainer/Rows/TabBar"), "signal": &"tab_changed"},
	{"path": NodePath("MarginContainer/Rows/InventoryBody/SortColumn/SortNameButton"), "signal": &"pressed"},
	{"path": NodePath("MarginContainer/Rows/InventoryBody/SortColumn/SortAmountButton"), "signal": &"pressed"},
	{"path": SEARCH_LINE_EDIT_PATH, "signal": &"text_changed"},
]

var _inventory_ui: Node
var _selection_context: Node
var _default_actor_path: NodePath
var _selected_actor_ref: WeakRef
var _selected_actor_display_name: String = "ロビン"
var _connected_inventory_module: Node


func _ready() -> void:
	_inventory_ui = get_parent()
	if _inventory_ui != null:
		_default_actor_path = _inventory_ui.get("actor_path")
	_connect_ui_refresh_signals()
	call_deferred("_connect_selection_context")


func _exit_tree() -> void:
	_disconnect_selection_context()
	_disconnect_inventory_signal()
	_disconnect_ui_refresh_signals()
	_selected_actor_ref = null


func _connect_selection_context() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var context := tree.get_first_node_in_group(SELECTION_CONTEXT_GROUP)
	if context == _selection_context:
		_apply_current_selection()
		return
	_disconnect_selection_context()
	_selection_context = context
	if _selection_context == null:
		_apply_actor(_get_default_actor())
		return
	var callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and not _selection_context.is_connected(&"selected_actor_changed", callable):
		_selection_context.connect(&"selected_actor_changed", callable)
	_apply_current_selection()


func _disconnect_selection_context() -> void:
	if _selection_context == null or not is_instance_valid(_selection_context):
		_selection_context = null
		return
	var callable := Callable(self, "_on_selected_actor_changed")
	if _selection_context.has_signal(&"selected_actor_changed") and _selection_context.is_connected(&"selected_actor_changed", callable):
		_selection_context.disconnect(&"selected_actor_changed", callable)
	_selection_context = null


func _apply_current_selection() -> void:
	if _selection_context == null or not _selection_context.has_method("get_selected_actor"):
		_apply_actor(_get_default_actor())
		return
	_on_selected_actor_changed(_selection_context.call("get_selected_actor") as Node)


func _on_selected_actor_changed(actor: Node) -> void:
	var target_actor := actor if _has_inventory(actor) else _get_default_actor()
	_apply_actor(target_actor)


func _apply_actor(actor: Node) -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	if actor == null or not is_instance_valid(actor):
		return
	var inventory := InventoryLookup.get_inventory_module(actor)
	if inventory == null:
		return

	var current_actor := _get_selected_actor()
	if current_actor == actor and _connected_inventory_module == inventory:
		_sync_title()
		return

	var previous_inventory := _get_inventory_ui_module()
	_disconnect_parent_inventory_refresh(previous_inventory)
	_disconnect_inventory_signal()

	_selected_actor_ref = weakref(actor)
	_selected_actor_display_name = _get_actor_display_name(actor, inventory)
	_connected_inventory_module = inventory
	_set_inventory_ui_actor_path(actor)
	_inventory_ui.set("_inventory_module", inventory)
	_inventory_ui.set("_current_category_index", 0)
	_inventory_ui.set("_current_page_index", 0)
	_inventory_ui.set("_search_query", "")
	_clear_search_text()
	_connect_inventory_signal(inventory)

	if _inventory_ui.has_method("_setup_tabs"):
		_inventory_ui.call("_setup_tabs")
	if _is_inventory_ui_visible() and _inventory_ui.has_method("_refresh"):
		_inventory_ui.call("_refresh")
	_sync_title()


func _connect_inventory_signal(inventory: Node) -> void:
	if inventory == null or not is_instance_valid(inventory):
		return
	_connected_inventory_module = inventory
	var callable := Callable(self, "_on_inventory_changed")
	if inventory.has_signal(&"inventory_changed") and not inventory.is_connected(&"inventory_changed", callable):
		inventory.connect(&"inventory_changed", callable)


func _disconnect_inventory_signal() -> void:
	if _connected_inventory_module != null and is_instance_valid(_connected_inventory_module):
		var callable := Callable(self, "_on_inventory_changed")
		if _connected_inventory_module.has_signal(&"inventory_changed") and _connected_inventory_module.is_connected(&"inventory_changed", callable):
			_connected_inventory_module.disconnect(&"inventory_changed", callable)
	_connected_inventory_module = null


func _disconnect_parent_inventory_refresh(inventory: Node) -> void:
	if inventory == null or not is_instance_valid(inventory):
		return
	var callable := Callable(_inventory_ui, "_refresh")
	if inventory.has_signal(&"inventory_changed") and inventory.is_connected(&"inventory_changed", callable):
		inventory.disconnect(&"inventory_changed", callable)


func _on_inventory_changed() -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	if _inventory_ui.has_method("_refresh"):
		_inventory_ui.call("_refresh")
	_sync_title()


func _connect_ui_refresh_signals() -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	var callable := Callable(self, "_on_inventory_ui_refreshed")
	if _inventory_ui.has_signal(&"visibility_changed") and not _inventory_ui.is_connected(&"visibility_changed", callable):
		_inventory_ui.connect(&"visibility_changed", callable)
	for target in REFRESH_SIGNAL_TARGETS:
		var node := _inventory_ui.get_node_or_null(target.get("path", NodePath("")))
		var signal_name: StringName = target.get("signal", &"")
		if node == null or signal_name == &"" or not node.has_signal(signal_name):
			continue
		if not node.is_connected(signal_name, callable):
			node.connect(signal_name, callable)


func _disconnect_ui_refresh_signals() -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	var callable := Callable(self, "_on_inventory_ui_refreshed")
	if _inventory_ui.has_signal(&"visibility_changed") and _inventory_ui.is_connected(&"visibility_changed", callable):
		_inventory_ui.disconnect(&"visibility_changed", callable)
	for target in REFRESH_SIGNAL_TARGETS:
		var node := _inventory_ui.get_node_or_null(target.get("path", NodePath("")))
		var signal_name: StringName = target.get("signal", &"")
		if node == null or signal_name == &"" or not node.has_signal(signal_name):
			continue
		if node.is_connected(signal_name, callable):
			node.disconnect(signal_name, callable)


func _on_inventory_ui_refreshed(_value: Variant = null) -> void:
	call_deferred("_sync_title")


func _sync_title() -> void:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return
	var title_label := _inventory_ui.get_node_or_null(TITLE_LABEL_PATH) as Label
	if title_label != null:
		title_label.text = "%sのインベントリ" % _selected_actor_display_name


func _clear_search_text() -> void:
	var search_line_edit := _inventory_ui.get_node_or_null(SEARCH_LINE_EDIT_PATH) as LineEdit
	if search_line_edit != null:
		search_line_edit.text = ""


func _set_inventory_ui_actor_path(actor: Node) -> void:
	if not _inventory_ui.is_inside_tree() or not actor.is_inside_tree():
		return
	_inventory_ui.set("actor_path", _inventory_ui.get_path_to(actor))


func _get_inventory_ui_module() -> Node:
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return null
	var value: Variant = _inventory_ui.get("_inventory_module")
	if value is Node:
		return value as Node
	return null


func _get_default_actor() -> Node:
	if _inventory_ui == null or _default_actor_path.is_empty():
		return null
	return _inventory_ui.get_node_or_null(_default_actor_path)


func _get_selected_actor() -> Node:
	if _selected_actor_ref == null:
		return null
	var actor := _selected_actor_ref.get_ref() as Node
	if actor == null or not is_instance_valid(actor):
		return null
	return actor


func _get_actor_display_name(actor: Node, inventory: Node) -> String:
	var display_name_value: Variant = actor.get("display_name")
	if display_name_value != null and not String(display_name_value).strip_edges().is_empty():
		return String(display_name_value)
	var owner_name_value: Variant = inventory.get("owner_display_name")
	if owner_name_value != null and not String(owner_name_value).strip_edges().is_empty():
		return String(owner_name_value)
	return actor.name


func _is_inventory_ui_visible() -> bool:
	return _inventory_ui is CanvasItem and (_inventory_ui as CanvasItem).visible


func _has_inventory(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	return InventoryLookup.get_inventory_module(actor) != null
