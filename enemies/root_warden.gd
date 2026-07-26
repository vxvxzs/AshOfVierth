class_name RootWarden
extends "res://scripts/enemies/enemy_base.gd"

func _draw() -> void:
	var color := Color("6f8b67") if flash_time_left <= 0.0 else Color("d9f0c0")
	if is_telegraphing():
		color = Color("c48864")
	draw_circle(Vector2(0, -5), 25.0, color)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 8), Vector2(22, 8), Vector2(13, 44), Vector2(-13, 44)]), Color("4a5f47"))
	draw_line(Vector2(-14, 28), Vector2(-34, 48), Color("7a563e"), 5.0)
	draw_line(Vector2(14, 28), Vector2(34, 48), Color("7a563e"), 5.0)
	if is_telegraphing():
		draw_arc(Vector2.ZERO, 66.0, facing_direction.angle() - 0.55, facing_direction.angle() + 0.55, 16, Color("ffb293"), 4.0, true)
