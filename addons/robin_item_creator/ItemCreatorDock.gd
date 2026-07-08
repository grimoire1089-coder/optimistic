@tool
extends VBoxContainer

const TITLE_TEXT := "Robin Item Creator"
const STATUS_TEXT := "最小構成です。まだ保存処理はありません。"


func _ready() -> void:
	_build_minimal_layout()


func _build_minimal_layout() -> void:
	if get_child_count() > 0:
		return
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var status := Label.new()
	status.text = STATUS_TEXT
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

	var note := Label.new()
	note.text = "この下部パネルに、FoodItemData作成、タグ選択、効果入力をモジュールとして追加します。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
