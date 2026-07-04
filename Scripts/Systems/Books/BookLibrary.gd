extends Node

signal library_changed

const SAVE_KEY := "owned_book_ids"
const READ_PAGES_SAVE_KEY := "book_read_pages"
const COMPLETED_BOOK_IDS_SAVE_KEY := "completed_book_ids"

@export var book_resource_paths: PackedStringArray = PackedStringArray([
	"res://Data/Books/Book_0001_LapisPrimer.tres",
	"res://Data/Books/Book_0002_DecadanceLivingGuide.tres",
	"res://Data/Books/Book_0101_CookingVol1.tres",
	"res://Data/Books/Book_0201_CapsuleFarmMushroomGuide.tres",
])

var _known_books: Dictionary = {}
var _known_book_ids_by_path: Dictionary = {}
var _owned_book_ids: Dictionary = {}
var _book_read_pages: Dictionary = {}
var _completed_book_ids: Dictionary = {}


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


func get_unlocked_travel_destinations() -> Array[Dictionary]:
	_load_known_books()
	var destinations: Array[Dictionary] = []
	var added_map_ids := {}

	for raw_id in _owned_book_ids.keys():
		var book := _known_books.get(raw_id, null) as BookData
		if book == null:
			continue
		if not book.has_travel_unlock():
			continue
		var map_id := book.get_unlock_travel_map_id()
		if map_id == &"" or added_map_ids.has(map_id):
			continue
		added_map_ids[map_id] = true
		destinations.append({
			"map_id": map_id,
			"display_name": book.get_unlock_travel_display_name(),
			"description": book.unlock_travel_description,
			"source_book_id": book.get_item_id(),
			"source_book_name": book.display_name,
		})

	return destinations


func is_travel_map_unlocked(map_id: StringName) -> bool:
	if map_id == &"":
		return false
	for destination in get_unlocked_travel_destinations():
		var destination_map_id := _get_map_id_from_destination(destination)
		if destination_map_id == map_id:
			return true
	return false


func get_read_pages(book_or_id: Variant) -> int:
	var book_id := _get_book_id_from_variant(book_or_id)
	if book_id == &"":
		return 0
	return maxi(int(_book_read_pages.get(book_id, 0)), 0)


func add_read_pages(book: BookData, page_delta: int) -> int:
	if book == null or page_delta <= 0:
		return 0
	register_book(book)
	var book_id := book.get_item_id()
	if book_id == &"":
		return 0
	var max_pages := maxi(book.page_count, 1)
	var next_pages := clampi(get_read_pages(book_id) + page_delta, 0, max_pages)
	_book_read_pages[book_id] = next_pages
	if next_pages >= max_pages:
		_completed_book_ids[book_id] = true
	library_changed.emit()
	return next_pages


func set_read_pages(book: BookData, pages: int) -> int:
	if book == null:
		return 0
	register_book(book)
	var book_id := book.get_item_id()
	if book_id == &"":
		return 0
	var max_pages := maxi(book.page_count, 1)
	var next_pages := clampi(pages, 0, max_pages)
	_book_read_pages[book_id] = next_pages
	if next_pages >= max_pages:
		_completed_book_ids[book_id] = true
	elif _completed_book_ids.has(book_id):
		_completed_book_ids.erase(book_id)
	library_changed.emit()
	return next_pages


func is_book_completed(book_or_id: Variant) -> bool:
	var book_id := _get_book_id_from_variant(book_or_id)
	if book_id == &"":
		return false
	return _completed_book_ids.has(book_id)


func mark_book_completed(book: BookData) -> void:
	if book == null:
		return
	register_book(book)
	var book_id := book.get_item_id()
	if book_id == &"":
		return
	_book_read_pages[book_id] = maxi(book.page_count, 1)
	_completed_book_ids[book_id] = true
	library_changed.emit()


func to_save_data() -> Dictionary:
	var ids: Array[String] = []
	for raw_id in _owned_book_ids.keys():
		ids.append(String(raw_id))
	ids.sort()

	var read_pages := {}
	for raw_id in _book_read_pages.keys():
		read_pages[String(raw_id)] = maxi(int(_book_read_pages[raw_id]), 0)

	var completed_ids: Array[String] = []
	for raw_id in _completed_book_ids.keys():
		completed_ids.append(String(raw_id))
	completed_ids.sort()

	return {
		SAVE_KEY: ids,
		READ_PAGES_SAVE_KEY: read_pages,
		COMPLETED_BOOK_IDS_SAVE_KEY: completed_ids,
	}


func apply_save_data(data: Dictionary) -> void:
	_owned_book_ids.clear()
	_book_read_pages.clear()
	_completed_book_ids.clear()
	if data.has(SAVE_KEY):
		var ids = data[SAVE_KEY]
		for raw_id in ids:
			var book_id := StringName(String(raw_id))
			if book_id != &"":
				_owned_book_ids[book_id] = true
	if data.has(READ_PAGES_SAVE_KEY):
		var read_pages = data[READ_PAGES_SAVE_KEY]
		if read_pages is Dictionary:
			for raw_id in read_pages.keys():
				var book_id := StringName(String(raw_id))
				if book_id != &"":
					_book_read_pages[book_id] = maxi(int(read_pages[raw_id]), 0)
	if data.has(COMPLETED_BOOK_IDS_SAVE_KEY):
		var completed_ids = data[COMPLETED_BOOK_IDS_SAVE_KEY]
		for raw_id in completed_ids:
			var book_id := StringName(String(raw_id))
			if book_id != &"":
				_completed_book_ids[book_id] = true
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


func _get_book_id_from_variant(value: Variant) -> StringName:
	if value is BookData:
		return (value as BookData).get_item_id()
	if value is StringName:
		return value
	return StringName(String(value))


func _get_map_id_from_destination(destination: Dictionary) -> StringName:
	var value: Variant = destination.get("map_id", &"")
	if value is StringName:
		return value
	return StringName(String(value))
