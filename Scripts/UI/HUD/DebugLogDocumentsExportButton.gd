extends Button
class_name DebugLogDocumentsExportButton

const EXPORT_SUB_DIRECTORY := "Optimistic/debug_logs"
const EXPORT_FILE_PREFIX := "debug_log"

@export var message_log_path: NodePath = NodePath("../../../..")
@export var tab_bar_path: NodePath = NodePath("../../LogTabBar")
@export var debug_tab_index: int = 3
@export var disabled_when_empty: bool = true

var _message_log: Node
var _tab_bar: TabBar


func _ready() -> void:
	text = "DOC"
	tooltip_text = "デバッグログをドキュメント/Optimistic/debug_logsへ出力"
	_resolve_refs()
	_connect_signals()
	_update_visibility()


func _process(_delta: float) -> void:
	_update_visibility()


func _on_pressed() -> void:
	_resolve_refs()
	var messages: PackedStringArray = _get_debug_messages()
	var directory_path: String = _get_export_directory_path()
	if directory_path.strip_edges().is_empty():
		_add_debug_message("ドキュメントフォルダを取得できませんでした。")
		return

	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	if make_dir_error != OK:
		_add_debug_message("ドキュメント側のデバッグログ出力フォルダを作成できませんでした: %s" % error_string(make_dir_error))
		return

	var file_path: String = directory_path.path_join("%s_%s.txt" % [EXPORT_FILE_PREFIX, _make_file_timestamp_text()])
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		_add_debug_message("ドキュメント側のデバッグログTXTを作成できませんでした: %s" % error_string(open_error))
		return

	file.store_string(_build_export_text(messages, file_path))
	file.close()
	_add_debug_message("デバッグログTXTをドキュメントへ出力しました: %s" % file_path)


func _get_debug_messages() -> PackedStringArray:
	if _message_log != null and _message_log.has_method("get_debug_messages"):
		return _message_log.call("get_debug_messages")
	return PackedStringArray()


func _build_export_text(messages: PackedStringArray, file_path: String) -> String:
	var lines: PackedStringArray = []
	lines.append("Optimistic Debug Log")
	lines.append("exported_at=%s" % _make_timestamp_text())
	lines.append("export_path=%s" % file_path)
	lines.append("message_count=%d" % messages.size())
	lines.append("---")
	for index in range(messages.size()):
		lines.append("%03d: %s" % [index + 1, messages[index]])
	return "\n".join(lines) + "\n"


func _get_export_directory_path() -> String:
	var documents_path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_path.strip_edges().is_empty():
		return ""
	return documents_path.path_join(EXPORT_SUB_DIRECTORY)


func _make_file_timestamp_text() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(stamp.get("year", 0)),
		int(stamp.get("month", 0)),
		int(stamp.get("day", 0)),
		int(stamp.get("hour", 0)),
		int(stamp.get("minute", 0)),
		int(stamp.get("second", 0)),
	]


func _make_timestamp_text() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(stamp.get("year", 0)),
		int(stamp.get("month", 0)),
		int(stamp.get("day", 0)),
		int(stamp.get("hour", 0)),
		int(stamp.get("minute", 0)),
		int(stamp.get("second", 0)),
	]


func _add_debug_message(message: String) -> void:
	if _message_log != null and _message_log.has_method("add_debug_message"):
		_message_log.call("add_debug_message", message)
	else:
		print(message)


func _connect_signals() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if _tab_bar != null and not _tab_bar.tab_changed.is_connected(_on_tab_changed):
		_tab_bar.tab_changed.connect(_on_tab_changed)


func _on_tab_changed(_tab: int) -> void:
	_update_visibility()


func _update_visibility() -> void:
	if _tab_bar != null:
		visible = _tab_bar.current_tab == debug_tab_index
	else:
		visible = true

	if disabled_when_empty:
		disabled = _get_debug_messages().is_empty()
	else:
		disabled = false


func _resolve_refs() -> void:
	if _message_log == null and not message_log_path.is_empty():
		_message_log = get_node_or_null(message_log_path)
	if _tab_bar == null and not tab_bar_path.is_empty():
		_tab_bar = get_node_or_null(tab_bar_path) as TabBar
