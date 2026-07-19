class_name PlayerAbilities
extends Node

const SHORT_STEP_SPEED := 420.0
const SHORT_STEP_DURATION := 0.14
const SHORT_STEP_COOLDOWN := 0.55
const SHORT_STEP_IFRAME_DURATION := 0.10

var short_step_unlocked := false
var dash_time_left := 0.0
var cooldown_time_left := 0.0
var invulnerability_time_left := 0.0
var dash_direction := Vector2.DOWN

func tick(delta: float) -> void:
	dash_time_left = maxf(0.0, dash_time_left - delta)
	cooldown_time_left = maxf(0.0, cooldown_time_left - delta)
	invulnerability_time_left = maxf(0.0, invulnerability_time_left - delta)

func try_dash(input_direction: Vector2, facing_direction: Vector2) -> bool:
	if not short_step_unlocked or cooldown_time_left > 0.0 or dash_time_left > 0.0:
		return false
	dash_direction = input_direction if input_direction != Vector2.ZERO else facing_direction
	dash_time_left = SHORT_STEP_DURATION
	cooldown_time_left = SHORT_STEP_COOLDOWN
	invulnerability_time_left = SHORT_STEP_IFRAME_DURATION
	return true

func unlock_short_step() -> void:
	short_step_unlocked = true

func is_dashing() -> bool:
	return dash_time_left > 0.0

func is_invulnerable() -> bool:
	return invulnerability_time_left > 0.0

func get_dash_velocity() -> Vector2:
	return dash_direction * SHORT_STEP_SPEED

func get_dash_direction() -> Vector2:
	return dash_direction
