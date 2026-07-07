extends RefCounted
class_name ShopRuntimeCache

const SHOP_DATABASE_PATH := "res://Data/Shops/ShopDatabase.tres"

static var _database: ShopDatabase
static var _database_path: String = ""
static var _shops: Array[ShopData] = []
static var _items_by_shop_tab: Dictionary = {}
static var _icons_by_path: Dictionary = {}
static var _version: int = 0
static var _is_prepared: bool = false


static func prepare_default_database() -> ShopDatabase:
	return prepare_database_path(SHOP_DATABASE_PATH)


static func prepare_database_path(database_path: String) -> ShopDatabase:
	if database_path.strip_edges().is_empty():
		return null
	if not ResourceLoader.exists(database_path):
		return null
	var loaded_database: ShopDatabase = ResourceLoader.load(database_path) as ShopDatabase
	prepare_database(loaded_database, database_path)
	return loaded_database


static func prepare_database(database: ShopDatabase, database_path: String = "") -> void:
	if database == null:
		return
	if _is_prepared and _database == database:
		return
	_database = database
	_database_path = database_path
	_shops = _database.get_shops()
	_is_prepared = true
	_version += 1


static func get_version() -> int:
	return _version


static func get_shops(database: ShopDatabase = null) -> Array[ShopData]:
	if database != null:
		prepare_database(database)
	elif not _is_prepared:
		prepare_default_database()
	return _shops.duplicate()
