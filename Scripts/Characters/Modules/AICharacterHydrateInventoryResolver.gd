extends RefCounted
class_name AICharacterHydrateInventoryResolver

const InventoryLookup := preload("res://Scripts/Characters/Modules/AICharacterInventoryLookup.gd")


static func resolve_inventory(
	owner: Node,
	actor: Node,
	inventory_module_path: NodePath,
	legacy_inventory_module_path: NodePath = NodePath("")
) -> Node:
	var inventory := InventoryLookup.get_inventory_module_from_path(owner, inventory_module_path)
	if inventory != null:
		return inventory

	inventory = InventoryLookup.get_inventory_module_from_path(owner, legacy_inventory_module_path)
	if inventory != null:
		return inventory

	return InventoryLookup.get_inventory_module(actor)
