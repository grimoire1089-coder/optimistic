extends RefCounted
class_name MessageLogTimestampModule

const FALLBACK_TIMESTAMP_TEXT := "ゲーム内時刻なし"


static func make_game_timestamp_text(owner: Node) -> String:
	var clock := find_game_clock(owner)
	if clock == null:
		return FALLBACK_TIMESTAMP_TEXT
	return "%s %s" % [clock.get_calendar_text(), clock.get_time_text()]


static func find_game_clock(owner: Node) -> GameClockSystem:
	if owner == null:
		return null
	if not owner.is_inside_tree():
		return null

	var autoload_clock := owner.get_node_or_null("/root/GameClock")
	if autoload_clock is GameClockSystem:
		return autoload_clock

	var group_nodes := owner.get_tree().get_nodes_in_group("game_clock")
	for node in group_nodes:
		if node is GameClockSystem:
			return node

	return null
