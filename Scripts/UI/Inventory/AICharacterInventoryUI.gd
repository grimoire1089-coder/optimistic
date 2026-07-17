extends "res://Scripts/UI/Inventory/RobinInventoryUI.gd"

const InventoryLookupBridge := preload("res://Scripts/Characters/Modules/AICharacterInventoryLookup.gd")

var _actor_ref: WeakRef
var _actor_display_name: String = "ロビン"
var _connected_inventory_module: Node


func _exit_tree() -> void:
	_disconnect_inventory_signal()
	_actor_ref = null


func set_actor(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var inventory := InventoryLookupBridge.get_inventory_module(
		actor,
		inventory_module_child_name,
		legacy_inventory_module_child_name
	)
	if inventory == null:
		return false

	var current_actor := _get_actor()
	if current_actor == actor and _inventory_module == inventory:
		_connect_inventory_signal(inventory)
		_update_actor_identity(actor)
		return true

	_disconnect_inventory_signal()
	_actor_ref = weakref(actor)
	_update_actor_identity(actor)
	_inventory_module = inventory
	_connect_inventory_signal(inventory)
	_reset_view_for_actor_change()
	if visible:
		_setup_tabs()
		_refresh()
	return true


func _resolve_inventory_module() -> void:
	if _inventory_module != null and is_instance_valid(_inventory_module):
		_connect_inventory_signal(_inventory_module)
		return

	var actor := _get_actor()
	if actor == null and not actor_path.is_empty():
		actor = get_node_or_null(actor_path)
	if actor == null:
		_disconnect_inventory_signal()
		_inventory_module = null
		return

	var inventory := InventoryLookupBridge.get_inventory_module(
		actor,
		inventory_module_child_name,
		legacy_inventory_module_child_name
	)
	if inventory == null:
		_disconnect_inventory_signal()
		_inventory_module = null
		push_warning("AIキャラクターのインベントリモジュールが見つかりません。")
		return

	_actor_ref = weakref(actor)
	_update_actor_identity(actor)
	_inventory_module = inventory
	_connect_inventory_signal(inventory)


func _refresh() -> void:
	super._refresh()
	if title_label != null:
		title_label.text = "%sのインベントリ" % _actor_display_name


func _reset_view_for_actor_change() -> void:
	_categories.clear()
	_current_category_index = 0
	_current_page_index = 0
	_search_query = ""
	if search_line_edit != null:
		search_line_edit.text = ""


func _connect_inventory_signal(inventory: Node) -> void:
	if inventory == null or not is_instance_valid(inventory):
		return
	if _connected_inventory_module == inventory:
		return
	_disconnect_inventory_signal()
	_connected_inventory_module = inventory
	var refresh_callable := Callable(self, "_refresh")
	if inventory.has_signal(&"inventory_changed") and not inventory.is_connected(&"inventory_changed", refresh_callable):
		inventory.connect(&"inventory_changed", refresh_callable)


func _disconnect_inventory_signal() -> void:
	if _connected_inventory_module != null and is_instance_valid(_connected_inventory_module):
		var refresh_callable := Callable(self, "_refresh")
		if _connected_inventory_module.has_signal(&"inventory_changed") and _connected_inventory_module.is_connected(&"inventory_changed", refresh_callable):
			_connected_inventory_module.disconnect(&"inventory_changed", refresh_callable)
	_connected_inventory_module = null


func _update_actor_identity(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if is_inside_tree() and actor.is_inside_tree():
		actor_path = get_path_to(actor)
	var display_name_value: Variant = actor.get("display_name")
	if display_name_value != null and not String(display_name_value).strip_edges().is_empty():
		_actor_display_name = String(display_name_value)
		return
	if _inventory_module != null:
		var owner_name_value: Variant = _inventory_module.get("owner_display_name")
		if owner_name_value != null and not String(owner_name_value).strip_edges().is_empty():
			_actor_display_name = String(owner_name_value)
			return
	_actor_display_name = actor.name


func _get_actor() -> Node:
	if _actor_ref == null:
		return null
	var actor := _actor_ref.get_ref() as Node
	if actor == null or not is_instance_valid(actor):
		return null
	return actor
