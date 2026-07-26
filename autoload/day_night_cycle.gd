extends Node

signal time_changed(day_index: int, minute_of_day: float)
signal phase_changed(phase: StringName)
signal lighting_state_changed(lights_enabled: bool)
signal day_changed(day_index: int)

const MINUTES_PER_DAY := 1440.0
const DEFAULT_DAY_DURATION_SECONDS := 720.0
const DEFAULT_START_MINUTE := 8.0 * 60.0
const DAWN_START_MINUTE := 5.0 * 60.0
const DAY_START_MINUTE := 8.0 * 60.0
const DUSK_START_MINUTE := 17.0 * 60.0
const NIGHT_START_MINUTE := 20.0 * 60.0
const LIGHTS_ON_MINUTE := 18.5 * 60.0
const LIGHTS_OFF_MINUTE := 6.0 * 60.0

const AMBIENT_KEYFRAMES: Array[Dictionary] = [
	{
		"minute": 0.0,
		"color": Color("30375f"),
	},
	{
		"minute": 5.0 * 60.0,
		"color": Color("48557b"),
	},
	{
		"minute": 7.25 * 60.0,
		"color": Color("ffd0a0"),
	},
	{
		"minute": 10.0 * 60.0,
		"color": Color("fff4db"),
	},
	{
		"minute": 15.5 * 60.0,
		"color": Color("fff0d3"),
	},
	{
		"minute": 18.5 * 60.0,
		"color": Color("d8887f"),
	},
	{
		"minute": 20.0 * 60.0,
		"color": Color("45466f"),
	},
	{
		"minute": 22.0 * 60.0,
		"color": Color("30375f"),
	},
]

var day_duration_seconds := DEFAULT_DAY_DURATION_SECONDS
var time_scale := 1.0
var paused := false
var day_index := 0
var minute_of_day := DEFAULT_START_MINUTE

var _phase: StringName = &"day"
var _lights_enabled := false
var _last_emitted_whole_minute := -1


func _ready() -> void:
	_refresh_derived_state(false)


func _process(delta: float) -> void:
	advance_real_seconds(delta)


func advance_real_seconds(real_seconds: float) -> void:
	if paused or real_seconds <= 0.0 or time_scale <= 0.0:
		return
	var minutes_per_second := (
		MINUTES_PER_DAY / maxf(day_duration_seconds, 1.0)
	)
	advance_minutes(real_seconds * minutes_per_second * time_scale)


func advance_minutes(minutes: float) -> void:
	if is_zero_approx(minutes):
		return
	var absolute_minutes := (
		float(day_index) * MINUTES_PER_DAY
		+ minute_of_day
		+ minutes
	)
	var next_day_index := floori(absolute_minutes / MINUTES_PER_DAY)
	var next_minute := fposmod(absolute_minutes, MINUTES_PER_DAY)
	var previous_day := day_index
	day_index = next_day_index
	minute_of_day = next_minute
	if previous_day != day_index:
		day_changed.emit(day_index)
	_refresh_derived_state(true)


func set_time(
	hour: int,
	minute: int = 0,
	new_day_index: int = -1
) -> void:
	if new_day_index >= 0:
		var previous_day := day_index
		day_index = new_day_index
		if previous_day != day_index:
			day_changed.emit(day_index)
	minute_of_day = fposmod(
		float(hour * 60 + minute),
		MINUTES_PER_DAY
	)
	_last_emitted_whole_minute = -1
	_refresh_derived_state(true)


func set_day_duration_seconds(seconds: float) -> void:
	day_duration_seconds = maxf(seconds, 1.0)


func set_time_scale(multiplier: float) -> void:
	time_scale = maxf(multiplier, 0.0)


func set_paused(value: bool) -> void:
	paused = value


func reset_clock(
	start_minute: float = DEFAULT_START_MINUTE,
	start_day: int = 0
) -> void:
	day_index = maxi(start_day, 0)
	minute_of_day = fposmod(start_minute, MINUTES_PER_DAY)
	day_duration_seconds = DEFAULT_DAY_DURATION_SECONDS
	time_scale = 1.0
	paused = false
	_last_emitted_whole_minute = -1
	_refresh_derived_state(true)


func get_hour_decimal() -> float:
	return minute_of_day / 60.0


func get_hour() -> int:
	return floori(minute_of_day / 60.0)


func get_minute() -> int:
	return floori(minute_of_day) % 60


func get_day_progress() -> float:
	return minute_of_day / MINUTES_PER_DAY


func get_phase() -> StringName:
	return _phase


func should_world_lights_be_enabled() -> bool:
	return _lights_enabled


func get_formatted_time() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func get_ambient_color() -> Color:
	var current_minute := minute_of_day
	for index in range(AMBIENT_KEYFRAMES.size()):
		var current: Dictionary = AMBIENT_KEYFRAMES[index]
		var next: Dictionary = AMBIENT_KEYFRAMES[
			(index + 1) % AMBIENT_KEYFRAMES.size()
		]
		var start_minute := float(current["minute"])
		var end_minute := float(next["minute"])
		var sample_minute := current_minute
		if index == AMBIENT_KEYFRAMES.size() - 1:
			end_minute += MINUTES_PER_DAY
			if sample_minute < start_minute:
				sample_minute += MINUTES_PER_DAY
		if sample_minute < start_minute or sample_minute > end_minute:
			continue
		var weight := inverse_lerp(
			start_minute,
			end_minute,
			sample_minute
		)
		return (
			current["color"] as Color
		).lerp(next["color"] as Color, weight)
	return Color.WHITE


func create_snapshot() -> Dictionary:
	return {
		"day_index": day_index,
		"minute_of_day": minute_of_day,
		"day_duration_seconds": day_duration_seconds,
		"time_scale": time_scale,
		"paused": paused,
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	day_index = maxi(int(snapshot.get("day_index", 0)), 0)
	minute_of_day = fposmod(
		float(snapshot.get("minute_of_day", DEFAULT_START_MINUTE)),
		MINUTES_PER_DAY
	)
	day_duration_seconds = maxf(
		float(
			snapshot.get(
				"day_duration_seconds",
				DEFAULT_DAY_DURATION_SECONDS
			)
		),
		1.0
	)
	time_scale = maxf(float(snapshot.get("time_scale", 1.0)), 0.0)
	paused = bool(snapshot.get("paused", false))
	_last_emitted_whole_minute = -1
	_refresh_derived_state(true)


func _refresh_derived_state(emit_time: bool) -> void:
	var next_phase := _calculate_phase()
	if next_phase != _phase:
		_phase = next_phase
		phase_changed.emit(_phase)
	var next_lights_enabled := (
		minute_of_day >= LIGHTS_ON_MINUTE
		or minute_of_day < LIGHTS_OFF_MINUTE
	)
	if next_lights_enabled != _lights_enabled:
		_lights_enabled = next_lights_enabled
		lighting_state_changed.emit(_lights_enabled)
	var whole_minute := floori(minute_of_day)
	if emit_time or whole_minute != _last_emitted_whole_minute:
		_last_emitted_whole_minute = whole_minute
		time_changed.emit(day_index, minute_of_day)


func _calculate_phase() -> StringName:
	if (
		minute_of_day >= DAWN_START_MINUTE
		and minute_of_day < DAY_START_MINUTE
	):
		return &"dawn"
	if (
		minute_of_day >= DAY_START_MINUTE
		and minute_of_day < DUSK_START_MINUTE
	):
		return &"day"
	if (
		minute_of_day >= DUSK_START_MINUTE
		and minute_of_day < NIGHT_START_MINUTE
	):
		return &"dusk"
	return &"night"
