extends Control

@export var clock_path: NodePath

@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel

var _clock: GameClockSystem


func _ready() -> void:
	_clock = _find_clock()

	if _clock == null:
		time_label.text = "--:--"
		phase_label.text = "時刻なし"
		push_warning("ClockDisplay: GameClockSystem が見つかりません。")
		return

	_clock.time_changed.connect(_on_time_changed)
	_clock.phase_changed.connect(_on_phase_changed)

	_refresh()


func _find_clock() -> GameClockSystem:
	if clock_path != NodePath():
		var node := get_node_or_null(clock_path)
		if node is GameClockSystem:
			return node

	var autoload_clock := get_node_or_null("/root/GameClock")
	if autoload_clock is GameClockSystem:
		return autoload_clock

	var group_nodes := get_tree().get_nodes_in_group("game_clock")
	if group_nodes.size() > 0 and group_nodes[0] is GameClockSystem:
		return group_nodes[0]

	return null


func _refresh() -> void:
	if _clock == null:
		return

	time_label.text = "%s  %s" % [
		_clock.get_day_text(),
		_clock.get_time_text(),
	]

	phase_label.text = _clock.get_phase_display_name()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_refresh()


func _on_phase_changed(_phase_id: String) -> void:
	_refresh()
