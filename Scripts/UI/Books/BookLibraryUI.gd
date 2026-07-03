extends PanelContainer
class_name BookLibraryUI

const BOTTOM_RIGHT_MARGIN := Vector2(24.0, 92.0)
const PANEL_SIZE := Vector2(420.0, 456.0)
const GENRES := [
	{"id": &"skill", "label": "スキル"},
	{"id": &"guide", "label": "ガイド"},
	{"id": &"novel", "label": "小説"},
	{"id": &"log", "label": "ログ"},
]

@export var reader_actor_path: NodePath = NodePath("../../Robin")

@onready var title_label: Label = $MarginContainer/Rows/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var genre_tabs: HBoxContainer = $MarginContainer/Rows/GenreTabs
@onready var book_list_scroll: ScrollContainer = $MarginContainer/Rows/Body/BookListScroll
@onready var book_list: VBoxContainer = $MarginContainer/Rows/Body/BookListScroll/BookList
@onready var empty_label: Label = $MarginContainer/Rows/Body/Reader/EmptyLabel
@onready var book_title_label: Label = $MarginContainer/Rows/Body/Reader/BookTitleLabel
@onready var book_meta_label: Label = $MarginContainer/Rows/Body/Reader/BookMetaLabel
@onready var read_button: Button = $MarginContainer/Rows/Body/Reader/ReadButton
@onready var reader_separator: HSeparator = $MarginContainer/Rows/Body/Reader/HSeparator
@onready var reader_scroll: ScrollContainer = $MarginContainer/Rows/Body/Reader/ReaderScroll
@onready var book_body_label: Label = $MarginContainer/Rows/Body/Reader/ReaderScroll/BookBodyLabel

var _selected_book_index: int = -1
var _selected_book_id: StringName = &""
var _current_genre_id: StringName = &"guide"
var _books: Array[BookData] = []


func _ready() -> void:
	visible = false
	add_to_group(&"book_library_ui")
	close_button.pressed.connect(close)
	read_button.pressed.connect(_on_read_button_pressed)
	_connect_library_signal()
	_apply_bottom_right_layout()
	call_deferred("_apply_bottom_right_layout")
	_refresh()


func open() -> void:
	_apply_bottom_right_layout()
	visible = true
	_refresh()


func close() -> void:
	visible = false


func close_menu() -> void:
	close()


func toggle() -> void:
	if visible:
		close()
		return
	open()


func toggle_library() -> void:
	toggle()


func _connect_library_signal() -> void:
	var library := _get_book_library()
	if library == null:
		return
	var callable := Callable(self, "_on_library_changed")
	if not library.is_connected("library_changed", callable):
		library.connect("library_changed", callable)


func _on_library_changed() -> void:
	_refresh()


func _refresh() -> void:
	_clear_book_list()
	_clear_genre_tabs()
	title_label.text = "書籍"

	var owned_books := _get_owned_books()
	_create_genre_tabs(owned_books)
	_books = _filter_books_by_genre(owned_books, _current_genre_id)

	if _books.is_empty():
		_show_empty_state(owned_books.is_empty())
		return

	_show_reader_state()
	_sync_selected_book_index()

	for index in range(_books.size()):
		book_list.add_child(_create_book_button(_books[index], index))

	_show_book(_books[_selected_book_index])


func _create_book_button(book: BookData, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(126.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.text = book.display_name
	button.tooltip_text = book.description
	button.disabled = index == _selected_book_index
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_book_button_style(false))
	button.add_theme_stylebox_override("hover", _make_book_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_book_button_style(true))
	button.add_theme_stylebox_override("disabled", _make_book_button_style(true))
	button.pressed.connect(Callable(self, "_on_book_button_pressed").bind(index))
	return button


func _on_book_button_pressed(index: int) -> void:
	_selected_book_index = index
	if index >= 0 and index < _books.size():
		_selected_book_id = _books[index].get_item_id()
	_refresh()


func _show_book(book: BookData) -> void:
	if book == null:
		return
	book_title_label.text = book.display_name
	if book.author_name.is_empty():
		book_meta_label.text = _make_book_meta_text(book, book.description)
	else:
		book_meta_label.text = _make_book_meta_text(book, "%s / %s" % [book.author_name, book.description])
	book_body_label.text = book.body_text
	_update_read_button(book)


func _on_read_button_pressed() -> void:
	var book := _get_selected_book()
	if book == null or not book.is_skill_book():
		return
	if _is_book_completed(book):
		return
	var actor := get_node_or_null(reader_actor_path)
	if actor == null or not actor.has_method("request_read_skill_book"):
		push_warning("Reader actor not found: %s" % reader_actor_path)
		return
	if actor.call("request_read_skill_book", book) == true:
		close()


func _create_genre_tabs(owned_books: Array[BookData]) -> void:
	for genre in GENRES:
		var genre_id := _get_genre_id_from_config(genre)
		var label := String(genre.get("label", ""))
		var count := _count_books_for_genre(owned_books, genre_id)
		genre_tabs.add_child(_create_genre_button(genre_id, label, count))


func _create_genre_button(genre_id: StringName, label: String, count: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(78.0, 30.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = "%s %d" % [label, count]
	button.tooltip_text = "%s の電子書籍" % label
	var is_active := genre_id == _current_genre_id
	button.disabled = is_active
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_genre_button_style(false))
	button.add_theme_stylebox_override("hover", _make_genre_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_genre_button_style(true))
	button.add_theme_stylebox_override("disabled", _make_genre_button_style(true))
	button.pressed.connect(Callable(self, "_on_genre_button_pressed").bind(genre_id))
	return button


func _on_genre_button_pressed(genre_id: StringName) -> void:
	if _current_genre_id == genre_id:
		return
	_current_genre_id = genre_id
	_selected_book_index = -1
	_selected_book_id = &""
	_refresh()


func _filter_books_by_genre(books: Array[BookData], genre_id: StringName) -> Array[BookData]:
	var filtered_books: Array[BookData] = []
	for book in books:
		if _get_book_genre_id(book) == genre_id:
			filtered_books.append(book)
	return filtered_books


func _count_books_for_genre(books: Array[BookData], genre_id: StringName) -> int:
	var count := 0
	for book in books:
		if _get_book_genre_id(book) == genre_id:
			count += 1
	return count


func _sync_selected_book_index() -> void:
	if _selected_book_id != &"":
		for index in range(_books.size()):
			if _books[index].get_item_id() == _selected_book_id:
				_selected_book_index = index
				return

	_selected_book_index = clampi(_selected_book_index, 0, _books.size() - 1)
	_selected_book_id = _books[_selected_book_index].get_item_id()


func _show_empty_state(no_owned_books: bool) -> void:
	_selected_book_index = -1
	_selected_book_id = &""
	book_list_scroll.visible = false
	empty_label.visible = true
	empty_label.text = "購入済みの電子書籍はありません。" if no_owned_books else "このジャンルの電子書籍はありません。"
	book_title_label.visible = false
	book_meta_label.visible = false
	read_button.visible = false
	reader_separator.visible = false
	reader_scroll.visible = false
	book_title_label.text = ""
	book_meta_label.text = ""
	book_body_label.text = ""


func _show_reader_state() -> void:
	book_list_scroll.visible = true
	empty_label.visible = false
	book_title_label.visible = true
	book_meta_label.visible = true
	read_button.visible = false
	reader_separator.visible = true
	reader_scroll.visible = true


func _make_book_meta_text(book: BookData, base_text: String) -> String:
	if book == null or not book.is_skill_book():
		return base_text
	var page_text := "%d/%dページ" % [_get_book_read_pages(book), maxi(book.page_count, 1)]
	if base_text.is_empty():
		return page_text
	return "%s / %s" % [base_text, page_text]


func _update_read_button(book: BookData) -> void:
	if book == null or not book.is_skill_book():
		read_button.visible = false
		read_button.disabled = true
		return
	read_button.visible = true
	var is_completed := _is_book_completed(book)
	read_button.text = "読破済み" if is_completed else "読む"
	read_button.disabled = is_completed


func _get_selected_book() -> BookData:
	if _selected_book_index < 0 or _selected_book_index >= _books.size():
		return null
	return _books[_selected_book_index]


func _get_book_read_pages(book: BookData) -> int:
	var library := _get_book_library()
	if book == null or library == null or not library.has_method("get_read_pages"):
		return 0
	return maxi(int(library.call("get_read_pages", book.get_item_id())), 0)


func _is_book_completed(book: BookData) -> bool:
	var library := _get_book_library()
	if book == null or library == null or not library.has_method("is_book_completed"):
		return false
	return library.call("is_book_completed", book.get_item_id()) == true


func _get_genre_id_from_config(genre: Dictionary) -> StringName:
	var raw_id = genre.get("id", &"guide")
	if raw_id is StringName:
		return raw_id
	return StringName(String(raw_id))


func _get_book_genre_id(book: BookData) -> StringName:
	if book == null:
		return &"guide"
	if book.has_method("get_genre_id"):
		var value = book.call("get_genre_id")
		if value is StringName:
			return value
		return StringName(String(value))
	return &"guide"


func _get_owned_books() -> Array[BookData]:
	var library := _get_book_library()
	if library == null or not library.has_method("get_books"):
		return []
	var books: Array[BookData] = []
	for raw_book in library.call("get_books"):
		if raw_book is BookData:
			books.append(raw_book)
	return books


func _get_book_library() -> Node:
	return get_node_or_null("/root/BookLibrary")


func _apply_bottom_right_layout() -> void:
	custom_minimum_size = PANEL_SIZE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -BOTTOM_RIGHT_MARGIN.x - PANEL_SIZE.x
	offset_top = -BOTTOM_RIGHT_MARGIN.y - PANEL_SIZE.y
	offset_right = -BOTTOM_RIGHT_MARGIN.x
	offset_bottom = -BOTTOM_RIGHT_MARGIN.y
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _clear_book_list() -> void:
	for child in book_list.get_children():
		child.queue_free()


func _clear_genre_tabs() -> void:
	for child in genre_tabs.get_children():
		child.queue_free()


func _make_book_button_style(is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.18, 0.20, 0.95) if is_active else Color(0.045, 0.05, 0.065, 0.98)
	style.border_color = Color(0.18, 0.82, 0.95, 0.95) if is_active else Color(0.12, 0.28, 0.34, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6.0)
	return style


func _make_genre_button_style(is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.20, 0.22, 0.98) if is_active else Color(0.045, 0.05, 0.065, 0.98)
	style.border_color = Color(0.20, 0.95, 1.0, 0.96) if is_active else Color(0.12, 0.28, 0.34, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5.0)
	return style
