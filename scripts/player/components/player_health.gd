class_name PlayerHealth
extends Node

signal health_changed(current_health: int, max_health: int)
signal died

const MAX_HEALTH := 3
const POST_HIT_INVULNERABILITY := 0.65
const FLASH_DURATION := 0.16

var current_health := MAX_HEALTH
var invulnerability_time_left := 0.0
var flash_time_left := 0.0
var dead := false

func tick(delta: float) -> void:
	invulnerability_time_left = maxf(0.0, invulnerability_time_left - delta)
	flash_time_left = maxf(0.0, flash_time_left - delta)

func take_damage(amount: int) -> bool:
	if dead or is_invulnerable():
		return false
	current_health = max(0, current_health - amount)
	invulnerability_time_left = POST_HIT_INVULNERABILITY
	flash_time_left = FLASH_DURATION
	health_changed.emit(current_health, MAX_HEALTH)
	if current_health == 0:
		dead = true
		died.emit()
	return true

func restore_full() -> void:
	dead = false
	current_health = MAX_HEALTH
	invulnerability_time_left = 0.0
	flash_time_left = 0.0
	health_changed.emit(current_health, MAX_HEALTH)

func is_invulnerable() -> bool:
	return invulnerability_time_left > 0.0

func is_flashing() -> bool:
	return flash_time_left > 0.0

func is_dead() -> bool:
	return dead
