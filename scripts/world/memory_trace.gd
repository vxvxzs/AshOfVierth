class_name MemoryTrace
extends Node2D

const GHOST_COLOR := Color("9edcff")
const CLOAK_COLOR := Color("556b99")

var pulse_time := 0.0
var memory_number := 1

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func set_memory_number(value: int) -> void:
	memory_number = value

func _draw() -> void:
	var pulse_alpha := 0.30 + sin(pulse_time * 2.4) * 0.10
	draw_circle(Vector2.ZERO, 28.0, Color(GHOST_COLOR, 0.08))
	draw_circle(Vector2.ZERO, 18.0, Color(GHOST_COLOR, pulse_alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(0, 30)]), Color(CLOAK_COLOR, pulse_alpha))
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 20, Color(GHOST_COLOR, pulse_alpha + 0.15), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-52, 54), "A past attempt", HORIZONTAL_ALIGNMENT_CENTER, 104, 14, Color(GHOST_COLOR, 0.75))
