extends Node
class_name AICharacterActionItemDisplayModule

@export var hydrate_behavior_path: NodePath = NodePath("../AICharacterHydrateBehaviorModule")
@export var craft_behavior_path: NodePath = NodePath("../AICharacterCraftBehaviorModule")
@export var sit_behavior_path: NodePath = NodePath("../AICharacterSitBehaviorModule")
@export var item_center_offset: Vector2 = Vector2(0.0, -18.0)
@export var item_display_size: Vector2 = Vector2(70.0, 70.0)
@export var item_z_index: int = 190

var _body: Node2D
var _hydrate_behavior: Node
var _craft_behavior: Node
var _sit_behavior: Node
var _item_rect: TextureRect
var _display_add_deferred := false
var _current_icon_path := ""


func _ready() -> void:
	_body = get_parent() as Node2D
	_resolve_refs()
	_request_display()
	set_process(true)


func setup(body: Node2D) -> void:
	_body = body
	_resolve_refs()
	_request_display()


func _process(_delta: float) -> void:
	_resolve_refs()
	_request_display()
	_update_display()


func _update_display() -> void:
	if _item_rect == null or not is_instance_valid(_item_rect):
		return
	var source := _get_active_item_source()
	if source == null:
		_item_rect.visible = false
		_current_icon_path = ""
		return

	var icon_path := ""
	if source.has_method("get_action_item_icon_path"):
		icon_path = String(source.call("get_action_item_icon_path"))
	if icon_path == "":
		_item_rect.visible = false
		_current_icon_path = ""
		return

	if icon_path != _current_icon_path:
		_current_icon_path = icon_path
		_item_rect.texture = _load_icon(icon_path)

	_item_rect.visible = _item_rect.texture != null
	_item_rect.size = item_display_size
	_item_rect.position = item_center_offset - item_display_size * 0.5


func _get_active_item_source() -> Node:
	if _craft_behavior != null and _should_show_source(_craft_behavior):
		return _craft_behavior
	if _hydrate_behavior != null and _should_show_source(_hydrate_behavior):
		return _hydrate_behavior
	if _sit_behavior != null and _should_show_source(_sit_behavior):
		return _sit_behavior
	return null


func _should_show_source(source: Node) -> bool:
	if source == null:
		return false
	if not source.has_method("is_action_item_display_visible"):
		return false
	return source.call("is_action_item_display_visible") == true


func _load_icon(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _request_display() -> void:
	if _item_rect != null and is_instance_valid(_item_rect):
		return
	if _display_add_deferred:
		return
	if _body == null:
		return
	_display_add_deferred = true
	call_deferred("_ensure_display_deferred")


func _ensure_display_deferred() -> void:
	_display_add_deferred = false
	_resolve_refs()
	if _item_rect != null and is_instance_valid(_item_rect):
		return
	if _body == null or not is_instance_valid(_body):
		return

	_item_rect = TextureRect.new()
	_item_rect.name = "AIActionItemDisplay"
	_item_rect.custom_minimum_size = item_display_size
	_item_rect.size = item_display_size
	_item_rect.position = item_center_offset - item_display_size * 0.5
	_item_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_rect.visible = false
	_item_rect.z_index = item_z_index
	_item_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_item_rect)


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as Node2D
	if _hydrate_behavior == null and not hydrate_behavior_path.is_empty():
		_hydrate_behavior = get_node_or_null(hydrate_behavior_path)
	if _craft_behavior == null and not craft_behavior_path.is_empty():
		_craft_behavior = get_node_or_null(craft_behavior_path)
	if _sit_behavior == null and not sit_behavior_path.is_empty():
		_sit_behavior = get_node_or_null(sit_behavior_path)
