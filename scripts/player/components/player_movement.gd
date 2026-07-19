class_name PlayerMovement
extends Node

const MAX_SPEED := 260.0
const ACCELERATION := 1900.0
const DECELERATION := 2200.0

func update_velocity(body: CharacterBody2D, input_direction: Vector2, speed_multiplier: float, delta: float) -> void:
	var target_velocity := input_direction * MAX_SPEED * speed_multiplier
	var rate := ACCELERATION if input_direction != Vector2.ZERO else DECELERATION
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
