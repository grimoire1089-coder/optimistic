extends Node

signal library_changed

const SAVE_KEY := "owned_book_ids"

@export var book_resource_paths: PackedStringArray = PackedStringArray([
	"res://Data/Books/Book_0001_LapisPrimer.tres",
	"res://Data/Books/Book_0002_DecadanceLivingGuide.tres",
])

var _known_books: Dictionary = {}
var _known_book_ids_by_path: Dictionary = {}
var _owned_book_ids: Dictionary = {}


func _ready() -> void:
	_load_known_books()
	library_changed.emit()


func register_book(book: BookData) -> void:
	if book == null:
		return
	var book_id := book.get_item_id()
	if book_id == &"":
		return
	_known_books[book_id] = book
	if not book.resource_path.is_empty():
		_known_book_ids_by_path[book.resource_path] = book_id


func add_book(book: BookData) -> bool:
	if book == null:
		return false
	register_book(book)
	var book_id := book.get_item_id()
	if book_id == &"":
		return false
	if _owned_book_ids.has(book_id):
		return false
	_owned_book_ids[book_id] = true
	library_changed.emit()
	return true


func has_book(book: BookData) -> bool:
	if book == null:
		return false
	return has_book_id(book.get_item_id())


func has_book_id(book_id: StringName) -> bool:
	return _owned_book_ids.has(book_id)


func get_books() -> Array[BookData]:
	_load_known_books()
	var books: Array[BookData] = []
	var added_ids := {}

	for path in book_resource_paths:
		var book := _load_book_from_path(path)
		if book == null:
			continue
		var book_id := book.get_item_id()
		if _owned_book_ids.has(book_id):
			books.append(book)
			added_ids[book_id] = true

	for raw_id in _owned_book_ids.keys():
		if added_ids.has(raw_id):
			continue
		var book := _known_books.get(raw_id, null) as BookData
		if book != null:
			books.append(book)

	return books


func get_book_count() -> int:
	return _owned_book_ids.size()


func to_save_data() -> Dictionary:
	var ids: Array[String] = []
	for raw_id in _owned_book_ids.keys():
		ids.append(String(raw_id))
	ids.sort()
	return {
		SAVE_KEY: ids,
	}


func apply_save_data(data: Dictionary) -> void:
	_owned_book_ids.clear()
	if data.has(SAVE_KEY):
		var ids = data[SAVE_KEY]
		for raw_id in ids:
			var book_id := StringName(String(raw_id))
			if book_id != &"":
				_owned_book_ids[book_id] = true
	_load_known_books()
	library_changed.emit()


func _load_known_books() -> void:
	for path in book_resource_paths:
		_load_book_from_path(path)


func _load_book_from_path(path: String) -> BookData:
	if path.is_empty():
		return null
	if _known_book_ids_by_path.has(path):
		var known_id: StringName = _known_book_ids_by_path[path]
		return _known_books.get(known_id, null) as BookData
	if not ResourceLoader.exists(path):
		return null
	var book := load(path) as BookData
	register_book(book)
	return book
