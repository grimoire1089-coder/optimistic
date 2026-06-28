extends Node
class_name GameClockNeedsBridge

@export var needs_module_path: NodePath
@export var game_minutes_per_tick: float = 1.0
@export var connect_on_ready: bool = true

var _needs_module: CharacterNeedsModule

func _ready() -> void:
	_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if connect_on_ready:
		connect_to_game_clock()

func connect_to_game_clock() -> void:
	var game_clock := get_node_or_null("/root/GameClock")
	if game_clock == null:
		return
	if not game_clock.has_signal("minute_changed"):
		return
	var callable := Callable(self, "_on_game_clock_minute_changed")
	if not game_clock.minute_changed.is_connected(callable):
		game_clock.minute_changed.connect(callable)

func set_needs_module(module: CharacterNeedsModule) -> void:
	_needs_module = module

func _on_game_clock_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	if _needs_module == null:
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if _needs_module == null:
		return
	_needs_module.tick_game_minutes(game_minutes_per_tick)
