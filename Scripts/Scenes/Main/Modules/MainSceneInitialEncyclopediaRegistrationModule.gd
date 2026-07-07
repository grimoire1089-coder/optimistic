extends Node
class_name MainSceneInitialEncyclopediaRegistrationModule

const DEFAULT_INITIAL_ITEM_PATHS := [
	"res://Data/Items/Tools/Lapis_001.tres",
]

@export var initial_item_paths: PackedStringArray = PackedStringArray(DEFAULT_INITIAL_ITEM_PATHS)
@export var notify_on_initial_registration: bool = false

var _has_registered: bool = false


func _ready() -> void:
	call_deferred("register_initial_items")


func register_initial_items() -> void:
	if _has_registered:
		return
	_has_registered = true

	var encyclopedia := get_node_or_null("/root/FoodEncyclopedia")
	if encyclopedia == null:
		return

	for item_path in initial_item_paths:
		_register_item_path(encyclopedia, String(item_path))


func _register_item_path(encyclopedia: Node, item_path: String) -> void:
	if encyclopedia == null:
		return
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		return

	var item_resource := load(item_path)
	if item_resource == null:
		return

	var item_id := _get_item_id(item_resource)
	if item_id == &"":
		return

	var display_name := _get_display_name(item_resource, item_path)
	if notify_on_initial_registration and encyclopedia.has_method("register_food_discovered"):
		encyclopedia.call("register_food_discovered", item_id, display_name)
		return
	if encyclopedia.has_method("register_initial_item_discovered"):
		encyclopedia.call("register_initial_item_discovered", item_id, display_name)
		return
	if encyclopedia.has_method("unlock_item_id"):
		encyclopedia.call("unlock_item_id", item_id, display_name)


func _get_item_id(item_resource: Resource) -> StringName:
	var raw_id: Variant = item_resource.get("item_id")
	if raw_id is StringName:
		return raw_id
	return StringName(String(raw_id))


func _get_display_name(item_resource: Resource, item_path: String) -> String:
	var display_name := String(item_resource.get("display_name")).strip_edges()
	if not display_name.is_empty():
		return display_name
	return item_path.get_file().get_basename()
