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
	if _is_prepared and _database_path == database_path and _database != null:
		return _database
	if not ResourceLoader.exists(database_path):
		return null
	var loaded_database: ShopDatabase = ResourceLoader.load(database_path) as ShopDatabase
	prepare_database(loaded_database, database_path)
	return loaded_database


static func prepare_database(database: ShopDatabase, database_path: String = "") -> void:
	if database == null:
		reset_cache()
		return
	if _is_prepared and _database == database:
		return
	_database = database
	_database_path = database_path
	_rebuild_cache()


static func reset_cache() -> void:
	_database = null
	_database_path = ""
	_shops = []
	_items_by_shop_tab = {}
	_icons_by_path = {}
	_is_prepared = false
	_version += 1


static func mark_cache_dirty() -> void:
	_is_prepared = false
	_shops = []
	_items_by_shop_tab = {}
	_icons_by_path = {}
	_version += 1


static func get_version() -> int:
	return _version


static func get_shops(database: ShopDatabase = null) -> Array[ShopData]:
	_ensure_prepared(database)
	return _shops.duplicate()


static func get_items_for_shop_tab(shop: ShopData, tab_id: StringName) -> Array[ShopItemData]:
	if shop == null:
		var empty_result: Array[ShopItemData] = []
		return empty_result
	if not _is_prepared:
		_rebuild_single_shop_cache(shop)
	var tab_key: String = _make_tab_cache_key(shop, tab_id)
	if not _items_by_shop_tab.has(tab_key):
		_cache_items_for_tab(shop, tab_id)
	return _copy_shop_item_array(_items_by_shop_tab.get(tab_key, []))


static func get_icon_for_entry(entry: ShopItemData) -> Texture2D:
	if entry == null:
		return null
	var icon_path: String = entry.get_icon_path()
	if icon_path.is_empty():
		return null
	var cached_icon: Texture2D = _icons_by_path.get(icon_path) as Texture2D
	if cached_icon != null:
		return cached_icon
	return _get_texture_from_path(icon_path)


static func get_shop_cache_key(shop: ShopData) -> String:
	return _make_shop_cache_key(shop)


static func get_tab_cache_key(shop: ShopData, tab_id: StringName) -> String:
	return _make_tab_cache_key(shop, tab_id)


static func _ensure_prepared(database: ShopDatabase) -> void:
	if database != null:
		prepare_database(database)
		return
	if not _is_prepared:
		prepare_default_database()


static func _rebuild_cache() -> void:
	_shops = []
	_items_by_shop_tab = {}
	if _database == null:
		_is_prepared = false
		_version += 1
		return
	_shops = _database.get_shops()
	for shop in _shops:
		_rebuild_single_shop_cache(shop)
	_is_prepared = true
	_version += 1


static func _rebuild_single_shop_cache(shop: ShopData) -> void:
	if shop == null:
		return
	_cache_items_for_tab(shop, &"")
	var tabs: Array[ShopTabData] = shop.get_tabs()
	for tab in tabs:
		_cache_items_for_tab(shop, tab.tab_id)
	var all_items: Array[ShopItemData] = shop.get_available_items()
	for entry in all_items:
		get_icon_for_entry(entry)


static func _cache_items_for_tab(shop: ShopData, tab_id: StringName) -> void:
	if shop == null:
		return
	var tab_key: String = _make_tab_cache_key(shop, tab_id)
	var entries: Array[ShopItemData] = shop.get_available_items_for_tab(tab_id)
	_items_by_shop_tab[tab_key] = entries


static func _get_texture_from_path(icon_path: String) -> Texture2D:
	if icon_path.is_empty():
		return null
	if _icons_by_path.has(icon_path):
		return _icons_by_path.get(icon_path) as Texture2D
	if not ResourceLoader.exists(icon_path):
		return null
	var texture: Texture2D = ResourceLoader.load(icon_path) as Texture2D
	if texture != null:
		_icons_by_path[icon_path] = texture
	return texture


static func _make_shop_cache_key(shop: ShopData) -> String:
	if shop == null:
		return ""
	var shop_id_text: String = String(shop.shop_id).strip_edges()
	if not shop_id_text.is_empty():
		return shop_id_text
	return "instance:%d" % shop.get_instance_id()


static func _make_tab_cache_key(shop: ShopData, tab_id: StringName) -> String:
	return "%s|%s" % [_make_shop_cache_key(shop), String(tab_id)]


static func _copy_shop_item_array(value: Variant) -> Array[ShopItemData]:
	var result: Array[ShopItemData] = []
	if not (value is Array):
		return result
	for entry in value:
		if entry is ShopItemData:
			result.append(entry as ShopItemData)
	return result
