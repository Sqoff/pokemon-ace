extends Node

signal time_period_changed(new_period: int, period_name: String, target_color: Color)
signal time_updated(hour: int, minute: int, period: int)

enum Period {
	MORNING = 0,
	DAY = 1,
	NIGHT = 2
}

const TINT_MORNING: Color = Color(1.0, 0.94, 0.82, 1.0)
const TINT_DAY: Color = Color(1.0, 1.0, 1.0, 1.0)
const TINT_NIGHT: Color = Color(0.48, 0.52, 0.78, 1.0)

var use_os_time: bool = true
var current_hour: int = 12
var current_minute: int = 0
var current_period: int = Period.DAY
var transition_duration: float = 0.0
var _os_poll_accum: float = 0.0


func _ready() -> void:
	if use_os_time:
		sync_with_os_time()


func _process(delta: float) -> void:
	if not use_os_time:
		return
	_os_poll_accum += delta
	if _os_poll_accum >= 10.0:
		_os_poll_accum = 0.0
		sync_with_os_time()


func get_period_for_hour(hour: int) -> int:
	var h: int = posmod(hour, 24)
	if h >= 4 and h < 10:
		return Period.MORNING
	elif h >= 10 and h < 18:
		return Period.DAY
	else:
		return Period.NIGHT


func get_period_name(period: int = -1) -> String:
	var p: int = current_period if period < 0 else period
	match p:
		Period.MORNING:
			return "MORNING"
		Period.DAY:
			return "DAY"
		Period.NIGHT:
			return "NIGHT"
	return "DAY"


func get_current_period_name() -> String:
	return get_period_name(current_period)


func get_current_period_display_name() -> String:
	match current_period:
		Period.MORNING:
			return "새벽/아침"
		Period.DAY:
			return "낮"
		Period.NIGHT:
			return "밤"
	return "낮"


func get_target_tint(period: int = -1) -> Color:
	var p: int = current_period if period < 0 else period
	match p:
		Period.MORNING:
			return TINT_MORNING
		Period.DAY:
			return TINT_DAY
		Period.NIGHT:
			return TINT_NIGHT
	return TINT_DAY


func sync_with_os_time() -> void:
	var time_dict: Dictionary = Time.get_time_dict_from_system()
	current_hour = int(time_dict.get("hour", 12))
	current_minute = int(time_dict.get("minute", 0))
	var new_period: int = get_period_for_hour(current_hour)
	var changed: bool = (new_period != current_period)
	current_period = new_period
	if changed:
		time_period_changed.emit(current_period, get_current_period_name(), get_target_tint(current_period))
	time_updated.emit(current_hour, current_minute, current_period)


func set_forced_hour(hour: int, immediate: bool = true) -> void:
	use_os_time = false
	current_hour = posmod(hour, 24)
	current_minute = 0
	current_period = get_period_for_hour(current_hour)
	var prev_dur: float = transition_duration
	if immediate:
		transition_duration = 0.0
	time_period_changed.emit(current_period, get_current_period_name(), get_target_tint(current_period))
	time_updated.emit(current_hour, current_minute, current_period)
	if immediate:
		transition_duration = prev_dur


func set_time_period(period: int, immediate: bool = true) -> void:
	use_os_time = false
	current_period = clampi(period, Period.MORNING, Period.NIGHT)
	match current_period:
		Period.MORNING:
			current_hour = 6
		Period.DAY:
			current_hour = 12
		Period.NIGHT:
			current_hour = 22
	current_minute = 0
	var prev_dur: float = transition_duration
	if immediate:
		transition_duration = 0.0
	time_period_changed.emit(current_period, get_current_period_name(), get_target_tint(current_period))
	time_updated.emit(current_hour, current_minute, current_period)
	if immediate:
		transition_duration = prev_dur


func cycle_next_period(immediate: bool = false) -> int:
	var next_p: int = (current_period + 1) % 3
	set_time_period(next_p, immediate)
	return current_period
