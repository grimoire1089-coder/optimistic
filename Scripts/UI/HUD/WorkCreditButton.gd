extends Button
class_name WorkCreditButton

@export var label_text: String = "仕事"
@export var work_menu_path: NodePath = NodePath("../WorkMenu")


func _ready() -> void:
	text = label_text
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var work_menu := get_node_or_null(work_menu_path) as WorkMenu
	if work_menu == null:
		push_warning("仕事UIが見つかりません: %s" % work_menu_path)
		return

	work_menu.open_menu()
