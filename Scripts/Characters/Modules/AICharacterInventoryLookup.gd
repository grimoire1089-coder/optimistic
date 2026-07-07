extends RefCounted
class_name AICharacterInventoryLookup

const PRIMARY_CHILD_NAME: StringName = &"AICharacterInventoryModule"
const LEGACY_CHILD_NAME: StringName = &""


static func get_inventory_module(
	actor: Node,
	preferred_child_name: StringName = PRIMARY_CHILD_NAME,
	legacy_child_name: StringName = LEGACY_CHILD_NAME
) -> Node:
	if actor == null:
		return null

	var inventory_from_method := _get_inventory_from_method(actor)
	if _is_inventory_compatible(inventory_from_method):
		return inventory_from_method

	var preferred_node := _get_child_inventory(actor, preferred_child_name)
	if _is_inventory_compatible(preferred_node):
		return preferred_node

	var legacy_node := _get_child_inventory(actor, legacy_child_name)
	if _is_inventory_compatible(legacy_node):
		return legacy_node

	return null


static func get_inventory_module_from_path(owner: Node, module_path: NodePath) -> Node:
	if owner == null or module_path.is_empty():
		return null
	var inventory := owner.get_node_or_null(module_path)
	if _is_inventory_compatible(inventory):
		return inventory
	return null


static func is_inventory_compatible(inventory: Node) -> bool:
	return _is_inventory_compatible(inventory)


static func _get_inventory_from_method(actor: Node) -> Node:
	if actor == null or not actor.has_method("get_inventory_module"):
		return null
	var value = actor.call("get_inventory_module")
	if value is Node:
		return value as Node
	return null


static func _get_child_inventory(actor: Node, child_name: StringName) -> Node:
	if actor == null or child_name == &"":
		return null
	return actor.get_node_or_null(NodePath(String(child_name)))


static func _is_inventory_compatible(inventory: Node) -> bool:
	if inventory == null:
		return false
	if not inventory.has_method("get_categories"):
		return false
	if not inventory.has_method("get_items"):
		return false
	if not inventory.has_method("add_item"):
		return false
	return true
