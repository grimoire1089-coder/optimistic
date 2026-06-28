extends Node
class_name GameClockSystem

signal time_changed(day: int, hour: int, minute: int)
signal minute_changed(day: int, hour: int, minute: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)
signal phase_changed(phase_id: String)

const MINUTES_PER_DAY := 24 * 60

const PHASE_DAWN := "dawn"
const PHASE_DAY := "day"
const PHASE_EVENING := "evening"
const PHASE_NIGHT := "night"

@export var start_day: int = 1
@export_range(0, 23, 1) var start_hour: int = 6
@export_range(0, 59, 1) var start_minute: int = 0

## 現実何秒でゲーム内1分進むか。
## 1.0 なら現実1秒 = ゲーム内1分。
@export var real_seconds_per_game_minute: float = 1.0

## Autoloadではタイトル画面中に進ませないため、初期値はfalse。
## TitleSceneの「はじめる」で reset_time() と start() を呼ぶ。
@export var auto_start: bool = false

var day: int = 1
var minute_of_day: int = 0

var is_running: bool = false
var is_clock_paused: bool = false

var _accumulator: float = 0.0
var _last_hour: int = -1
var _last_phase_id: String = ""


func _ready() -> void:
	add_to_group("game_clock")
	reset_time()

	if auto_start:
		start()


func _process(delta: float) -> void:
	if not is_running:
		return

	if is_clock_paused:
		return

	if real_seconds_per_game_minute <= 0.0:
		return

	_accumulator += delta

	while _accumulator >= real_seconds_per_game_minute:
		_accumulator -= real_seconds_per_game_minute
		advance_minutes(1)


func reset_time() -> void:
	day = max(1, start_day)
	minute_of_day = clamp(start_hour, 0, 23) * 60 + clamp(start_minute, 0, 59)
	_accumulator = 0.0
	_last_hour = get_hour()
	_last_phase_id = get_phase_id()

	emit_time_signals(true)


func start() -> void:
	is_running = true


func stop() -> void:
	is_running = false


func set_clock_paused(paused: bool) -> void:
	is_clock_paused = paused


func advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return

	for i in range(minutes):
		_advance_one_minute()


func set_time(new_day: int, new_hour: int, new_minute: int) -> void:
	day = max(1, new_day)
	minute_of_day = clamp(new_hour, 0, 23) * 60 + clamp(new_minute, 0, 59)
	_accumulator = 0.0

	emit_time_signals(true)


func get_hour() -> int:
	return floori(float(minute_of_day) / 60.0)


func get_minute() -> int:
	return minute_of_day % 60


func get_time_text() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func get_day_text() -> String:
	return "Day %d" % day


func get_phase_id() -> String:
	var hour := get_hour()

	if hour >= 5 and hour < 10:
		return PHASE_DAWN

	if hour >= 10 and hour < 17:
		return PHASE_DAY

	if hour >= 17 and hour < 21:
		return PHASE_EVENING

	return PHASE_NIGHT


func get_phase_display_name() -> String:
	match get_phase_id():
		PHASE_DAWN:
			return "朝"
		PHASE_DAY:
			return "昼"
		PHASE_EVENING:
			return "夕方"
		PHASE_NIGHT:
			return "夜"
		_:
			return "不明"


func get_save_data() -> Dictionary:
	return {
		"day": day,
		"minute_of_day": minute_of_day,
		"is_running": is_running,
		"is_clock_paused": is_clock_paused,
	}


func apply_save_data(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minute_of_day = int(data.get("minute_of_day", 6 * 60))
	is_running = bool(data.get("is_running", true))
	is_clock_paused = bool(data.get("is_clock_paused", false))

	day = max(1, day)
	minute_of_day = clamp(minute_of_day, 0, MINUTES_PER_DAY - 1)

	_accumulator = 0.0
	emit_time_signals(true)


func emit_time_signals(force: bool = false) -> void:
	var hour := get_hour()
	var minute := get_minute()
	var phase_id := get_phase_id()

	time_changed.emit(day, hour, minute)
	minute_changed.emit(day, hour, minute)

	if force or hour != _last_hour:
		_last_hour = hour
		hour_changed.emit(day, hour)

	if force or phase_id != _last_phase_id:
		_last_phase_id = phase_id
		phase_changed.emit(phase_id)


func _advance_one_minute() -> void:
	var old_hour := get_hour()
	var old_phase_id := get_phase_id()

	minute_of_day += 1

	if minute_of_day >= MINUTES_PER_DAY:
		minute_of_day = 0
		day += 1
		day_changed.emit(day)

	var new_hour := get_hour()
	var new_phase_id := get_phase_id()
	var new_minute := get_minute()

	time_changed.emit(day, new_hour, new_minute)
	minute_changed.emit(day, new_hour, new_minute)

	if new_hour != old_hour:
		hour_changed.emit(day, new_hour)

	if new_phase_id != old_phase_id:
		phase_changed.emit(new_phase_id)

	_last_hour = new_hour
	_last_phase_id = new_phase_id
