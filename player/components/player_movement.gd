class_name PlayerMovement
extends Node

@export_category("Locomotion")
@export_range(60.0, 240.0, 1.0) var max_speed := 135.0
@export_range(100.0, 2000.0, 10.0) var acceleration := 580.0
@export_range(100.0, 2400.0, 10.0) var deceleration := 820.0
@export_range(100.0, 2400.0, 10.0) var turn_acceleration := 1050.0
@export_range(100.0, 2400.0, 10.0) var friction := 1050.0

func update_velocity(body: CharacterBody2D, input_direction: Vector2, speed_multiplier: float, delta: float) -> void:
	var movement_input := input_direction.limit_length(1.0)
	if movement_input.is_zero_approx():
		body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * delta)
		return
	var target_velocity := movement_input * max_speed * maxf(speed_multiplier, 0.0)
	var target_direction := target_velocity.normalized()
	var current_speed_toward_target := body.velocity.dot(target_direction)
	var rate := acceleration if current_speed_toward_target < target_velocity.length() else deceleration
	if not body.velocity.is_zero_approx() and body.velocity.normalized().dot(target_direction) < 0.65:
		rate = turn_acceleration
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
