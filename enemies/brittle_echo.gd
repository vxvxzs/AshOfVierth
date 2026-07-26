class_name BrittleEcho
extends "res://scripts/enemies/enemy_base.gd"

const BODY_RADIUS := 19.0
const BODY_COLOR := Color("9875bd")
const HURT_COLOR := Color("f1c9ff")
const TELEGRAPH_COLOR := Color("ff8f8f")

func _draw() -> void:
	var color := HURT_COLOR if flash_time_left > 0.0 else BODY_COLOR
	if is_telegraphing():
		color = TELEGRAPH_COLOR
	draw_circle(Vector2.ZERO, BODY_RADIUS, color)
	draw_arc(Vector2.ZERO, BODY_RADIUS + 6.0, -2.2, 0.7, 12, Color("d8b7ef", 0.75), 2.0, true)
	draw_circle(Vector2(-6, -3), 2.0, Color("1d1527"))
	draw_circle(Vector2(6, -3), 2.0, Color("1d1527"))
	if is_telegraphing():
		draw_arc(Vector2.ZERO, 48.0, facing_direction.angle() - 0.6, facing_direction.angle() + 0.6, 12, Color(TELEGRAPH_COLOR, 0.9), 3.0, true)
