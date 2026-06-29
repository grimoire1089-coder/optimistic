extends Resource
class_name ShopDatabase

@export var shops: Array[ShopData] = []


func get_shops() -> Array[ShopData]:
	var result: Array[ShopData] = []
	for shop in shops:
		if shop == null:
			continue
		result.append(shop)
	return result


func find_shop_by_id(shop_id: StringName) -> ShopData:
	for shop in shops:
		if shop == null:
			continue
		if shop.shop_id == shop_id:
			return shop
	return null
