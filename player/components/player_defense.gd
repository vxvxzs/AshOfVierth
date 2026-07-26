class_name PlayerDefense
extends Node

const PARRY_WINDOW := 0.22
const PARRY_COOLDOWN := 0.58

var parry_time_left := 0.0
var parry_cooldown_left := 0.0

func tick(delta: float) -> void:
	parry_time_left = maxf(0.0, parry_time_left - delta)
	parry_cooldown_left = maxf(0.0, parry_cooldown_left - delta)

func try_parry() -> bool:
	if parry_cooldown_left > 0.0:
		return false
	parry_time_left = PARRY_WINDOW
	parry_cooldown_left = PARRY_COOLDOWN
	return true

func is_parrying() -> bool:
	return parry_time_left > 0.0
