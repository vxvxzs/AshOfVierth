class_name AshWarden
extends "res://scripts/enemies/enemy_base.gd"

signal enraged

var is_enraged := false

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if not has_reported_defeat and not is_enraged and health <= max_health / 2:
		is_enraged = true
		move_speed *= 1.35
		telegraph_duration *= 0.72
		enraged.emit()

func _on_defeated() -> void:
	WorldState.set_flag(&"ash_forest_boss_defeated")

func _draw() -> void:
	var color := Color("b85b50") if not is_enraged else Color("e36f57")
	if flash_time_left > 0.0:
		color = Color("ffe4bd")
	draw_circle(Vector2(0, -6), 38.0, color)
	draw_colored_polygon(PackedVector2Array([Vector2(-33, 18), Vector2(33, 18), Vector2(24, 66), Vector2(-24, 66)]), Color("542f39"))
	draw_arc(Vector2.ZERO, 49.0, 0.0, TAU, 28, Color("f1b57d"), 3.0, true)
	draw_circle(Vector2(-13, -12), 4.0, Color("24131b"))
	draw_circle(Vector2(13, -12), 4.0, Color("24131b"))
	draw_rect(Rect2(-48, -70, 96, 8), Color("231923"), true)
	draw_rect(Rect2(-48, -70, 96.0 * maxf(0.0, float(health) / float(max_health)), 8), Color("df7961"), true)
	if is_telegraphing():
		draw_arc(Vector2.ZERO, 86.0, facing_direction.angle() - 0.65, facing_direction.angle() + 0.65, 18, Color("ffc097"), 5.0, true)
