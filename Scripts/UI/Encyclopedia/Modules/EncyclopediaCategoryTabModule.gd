extends Node
class_name EncyclopediaCategoryTabModule

const CATEGORY_FOODS := "foods"
const CATEGORY_TOOLS := "tools"
const CATEGORY_DRINKS := "drinks"
const CATEGORY_INGREDIENTS := "ingredients"
const CATEGORY_IDS := [CATEGORY_TOOLS, CATEGORY_FOODS, CATEGORY_DRINKS, CATEGORY_INGREDIENTS]


func get_category_ids() -> Array[String]:
	var result: Array[String] = []
	for category_id in CATEGORY_IDS:
		result.append(String(category_id))
	return result


func get_tab_title(category_id: String) -> String:
	match category_id:
		CATEGORY_FOODS:
			return "食品"
		CATEGORY_TOOLS:
			return "ツール"
		CATEGORY_DRINKS:
			return "飲料"
		CATEGORY_INGREDIENTS:
			return "食材"
		_:
			return category_id


func get_page_name(category_id: String) -> String:
	match category_id:
		CATEGORY_FOODS:
			return "FoodPage"
		CATEGORY_TOOLS:
			return "ToolPage"
		CATEGORY_DRINKS:
			return "DrinkPage"
		CATEGORY_INGREDIENTS:
			return "IngredientPage"
		_:
			return ""


func get_tab_hint(category_id: String) -> String:
	match category_id:
		CATEGORY_FOODS:
			return "料理や完成食品を記録する図鑑ページ。"
		CATEGORY_TOOLS:
			return "生活や制作に使う道具を記録する図鑑ページ。"
		CATEGORY_DRINKS:
			return "水分補給や休息に使う飲料を記録する図鑑ページ。"
		CATEGORY_INGREDIENTS:
			return "調理や制作の材料になる食材を記録する図鑑ページ。"
		_:
			return "図鑑ページ。"


func get_empty_name(category_id: String) -> String:
	return "%sテンプレート" % get_tab_title(category_id)


func get_empty_description(category_id: String) -> String:
	match category_id:
		CATEGORY_FOODS:
			return "食品タブ用の図鑑テンプレートです。ここに料理や完成食品の世界観説明を追加していきます。"
		CATEGORY_TOOLS:
			return "ツールタブ用の図鑑テンプレートです。ここに生活道具や端末の説明を追加していきます。"
		CATEGORY_DRINKS:
			return "飲料タブ用の図鑑テンプレートです。ここに飲み物や水分補給アイテムの説明を追加していきます。"
		CATEGORY_INGREDIENTS:
			return "食材タブ用の図鑑テンプレートです。ここに調理素材や保存食材の説明を追加していきます。"
		_:
			return "図鑑テンプレートです。"


func get_flavor_text(category_id: String) -> String:
	match category_id:
		CATEGORY_FOODS:
			return "Felicityの温もり、街区ごとの食文化、住民たちの好物や思い出をここに重ねていく。"
		CATEGORY_TOOLS:
			return "ロビンたちの暮らしを支える端末、工具、制作道具の記録をここに重ねていく。"
		CATEGORY_DRINKS:
			return "休息、水分補給、語らいの一杯。デカダンスの日常を潤す飲み物の記録。"
		CATEGORY_INGREDIENTS:
			return "厨房、栽培、依頼達成を支える素材たち。料理の始まりになる食材の記録。"
		_:
			return "デカダンス生活図鑑の記録。"
