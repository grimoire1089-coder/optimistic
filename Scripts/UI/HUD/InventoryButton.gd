extends Button
class_name InventoryButton

@export var inventory_ui_path: NodePath = NodePath("../InventoryUI")
@export var fallback_group_name: StringName = &"inventory_ui"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var inventory_ui := _find_inventory_ui()
	if inventory_ui == null:
		push_warning("インベントリUIが見つかりません: %s" % inventory_ui_path)
		return

	_open_or_toggle_inventory(inventory_ui)


func _find_inventory_ui() -> Node:
	var inventory_ui := get_node_or_null(inventory_ui_path)
	if inventory_ui != null:
		return inventory_ui

	return get_tree().get_first_node_in_group(fallback_group_name)


func _open_or_toggle_inventory(inventory_ui: Node) -> void:
	if inventory_ui.has_method("toggle_inventory"):
		inventory_ui.call("toggle_inventory")
		return

	if inventory_ui.has_method("toggle"):
		inventory_ui.call("toggle")
		return

	if inventory_ui.has_method("open"):
		inventory_ui.call("open")
		return

	if inventory_ui is CanvasItem:
		var canvas_item := inventory_ui as CanvasItem
		canvas_item.visible = not canvas_item.visible
		return

	push_warning("インベントリUIを開く方法が見つかりません: %s" % inventory_ui.name)
