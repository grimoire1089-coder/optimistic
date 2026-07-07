extends PanelContainer
class_name CityPanel

const ResidentsPagePresenter := preload("res://Scripts/UI/City/Modules/CityResidentsPagePresenter.gd")
const RelationshipStore := preload("res://Scripts/UI/City/Modules/CityRelationshipStore.gd")

@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var map_travel_module_path: NodePath = NodePath("../../MainSceneMapTravelModule")
@export var center_on_map_grid: bool = true
@export var resident_data_paths: Array[String] = ["res://Data/NPC/Residents/Npc_Zippy.tres"]
@export var relationship_data_paths: Array[String] = ["res://Data/NPC/Relationships/Relationship_Zippy_Robin.tres"]

const MAP_CENTER_PANEL_SIZE := Vector2(760.0, 760.0)
const PAGE_NONE := &""
const PAGE_RESIDENTS := &"residents"
const PAGE_INVESTMENT := &"investment"

@onready var close_button: Button = $MarginContainer/Rows/Header/CloseButton
@onready var guide_label: Label = $MarginContainer/Rows/Body/ContentRows/GuideLabel
@onready var residents_button: Button = $MarginContainer/Rows/Body/ContentRows/PageButtonRow/ResidentsPageButton
@onready var investment_button: Button = $MarginContainer/Rows/Body/ContentRows/PageButtonRow/InvestmentPageButton
@onready var residents_page: Control = $MarginContainer/Rows/Body/ContentRows/Pages/ResidentsPage
@onready var investment_page: Control = $MarginContainer/Rows/Body/ContentRows/Pages/InvestmentPage
@onready var resident_list: VBoxContainer = $MarginContainer/Rows/Body/ContentRows/Pages/ResidentsPage/MarginContainer/Rows/ResidentScroll/ResidentList

var _room_map: RoomMapGridModule
var _map_travel_module: Node
var _layout_room_map: RoomMapGridModule
var _current_page: StringName = PAGE_NONE
var _resident_cache: Array[NpcResidentData] = []
var _relationship_cache: Dictionary = {}


func _ready() -> void:
	visible = false
	add_to_group(&"city_panel")
	_apply_map_center_layout()
	call_deferred("_apply_map_center_layout")
	if close_button != null:
		close_button.text = "X"
		close_button.pressed.connect(close_menu)
	if residents_button != null:
		residents_button.pressed.connect(_on_residents_page_pressed)
	if investment_button != null:
		investment_button.pressed.connect(_on_investment_page_pressed)
	_reload_residents()
	_reload_relationships()
	_refresh_residents_page()
	_show_page(PAGE_NONE)


func open_menu() -> void:
	_apply_map_center_layout()
	visible = true


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
		return
	open_menu()


func _exit_tree() -> void:
	_disconnect_map_rect_signal()


func _on_residents_page_pressed() -> void:
	_refresh_residents_page()
	_show_page(PAGE_RESIDENTS)


func _on_investment_page_pressed() -> void:
	_show_page(PAGE_INVESTMENT)


func _show_page(page_id: StringName) -> void:
	_current_page = page_id
	if residents_page != null:
		residents_page.visible = page_id == PAGE_RESIDENTS
	if investment_page != null:
		investment_page.visible = page_id == PAGE_INVESTMENT
	if residents_button != null:
		residents_button.button_pressed = page_id == PAGE_RESIDENTS
	if investment_button != null:
		investment_button.button_pressed = page_id == PAGE_INVESTMENT
	if guide_label == null:
		return
	guide_label.visible = page_id == PAGE_NONE
	if page_id == PAGE_NONE:
		guide_label.text = "街で確認したい項目を選んでください。"


func _reload_residents() -> void:
	_resident_cache.clear()
	for data_path in resident_data_paths:
		if data_path.is_empty() or not ResourceLoader.exists(data_path):
			continue
		var resident := load(data_path) as NpcResidentData
		if resident != null:
			_resident_cache.append(resident)


func _reload_relationships() -> void:
	_relationship_cache = RelationshipStore.load_relationships(relationship_data_paths)


func _refresh_residents_page() -> void:
	ResidentsPagePresenter.rebuild(resident_list, _resident_cache, _relationship_cache)


func _apply_map_center_layout() -> void:
	if not center_on_map_grid:
		return

	var panel_size := MAP_CENTER_PANEL_SIZE
	custom_minimum_size = panel_size
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	var center := _get_map_layout_center()
	var half_size := panel_size * 0.5
	offset_left = round(center.x - half_size.x)
	offset_top = round(center.y - half_size.y)
	offset_right = round(center.x + half_size.x)
	offset_bottom = round(center.y + half_size.y)


func _get_map_layout_center() -> Vector2:
	var active_map := _get_active_room_map()
	_connect_map_rect_signal(active_map)
	if active_map != null:
		var grid_rect := active_map.get_grid_rect()
		if grid_rect.size.x > 0.0 and grid_rect.size.y > 0.0:
			return grid_rect.get_center()

	var viewport_rect := get_viewport_rect()
	return viewport_rect.position + viewport_rect.size * 0.5


func _get_active_room_map() -> RoomMapGridModule:
	var travel_module := _get_map_travel_module()
	if travel_module != null and travel_module.has_method("get_active_map"):
		var active_map := travel_module.call("get_active_map") as RoomMapGridModule
		if active_map != null:
			return active_map
	return _get_room_map()


func _get_map_travel_module() -> Node:
	if _map_travel_module != null and is_instance_valid(_map_travel_module):
		return _map_travel_module
	_map_travel_module = get_node_or_null(map_travel_module_path)
	return _map_travel_module


func _get_room_map() -> RoomMapGridModule:
	if _room_map != null and is_instance_valid(_room_map):
		return _room_map
	_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	return _room_map


func _connect_map_rect_signal(room_map: RoomMapGridModule) -> void:
	if _layout_room_map == room_map:
		return
	_disconnect_map_rect_signal()
	_layout_room_map = room_map
	if _layout_room_map == null:
		return

	var callable := Callable(self, "_on_room_map_rect_changed")
	if not _layout_room_map.map_rect_changed.is_connected(callable):
		_layout_room_map.map_rect_changed.connect(callable)


func _disconnect_map_rect_signal() -> void:
	if _layout_room_map == null or not is_instance_valid(_layout_room_map):
		_layout_room_map = null
		return

	var callable := Callable(self, "_on_room_map_rect_changed")
	if _layout_room_map.map_rect_changed.is_connected(callable):
		_layout_room_map.map_rect_changed.disconnect(callable)
	_layout_room_map = null


func _on_room_map_rect_changed(_visual_rect: Rect2, _grid_rect: Rect2, _grid_size: Vector2i) -> void:
	if visible:
		call_deferred("_apply_map_center_layout")
