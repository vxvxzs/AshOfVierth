class_name AshHound
extends "res://scripts/enemies/enemy_base.gd"

func _draw() -> void:
	var color := Color("e29b6d") if flash_time_left <= 0.0 else Color("ffe1b8")
	if is_telegraphing():
		color = Color("ff7e78")
	draw_ellipse(Vector2.ZERO, Vector2(25, 14), color)
	draw_circle(Vector2(18, -5), 11.0, color)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -7), Vector2(-37, -18), Vector2(-26, 4)]), Color("9a5a4a"))
	draw_circle(Vector2(22, -7), 2.5, Color("241a22"))
	if is_telegraphing():
		draw_arc(Vector2.ZERO, 44.0, facing_direction.angle() - 0.7, facing_direction.angle() + 0.7, 14, Color("ff8f8f"), 3.0, true)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
