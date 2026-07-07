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
