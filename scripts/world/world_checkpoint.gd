class_name WorldCheckpoint
extends Node2D

signal activated(checkpoint)

const ANCHOR_COLOR := Color("8ee6e8")

@export var anchor_id: StringName = &"ash_well"

var is_active := false

func activate() -> void:
	if is_active:
		return
	is_active = true
	WorldState.set_anchor(anchor_id, get_spawn_position())
	SaveManager.save_world_state()
	activated.emit(self)
	queue_redraw()

func get_spawn_position() -> Vector2:
	return global_position + Vector2(0, -48)

func _draw() -> void:
	var outer_color := Color(ANCHOR_COLOR, 0.9 if is_active else 0.35)
	draw_circle(Vector2.ZERO, 26.0, Color(ANCHOR_COLOR, 0.18 if is_active else 0.08))
	draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 20, outer_color, 2.0, true)
	draw_circle(Vector2.ZERO, 12.0, outer_color)
	draw_string(ThemeDB.fallback_font, Vector2(-42, 52), "ASH WELL", HORIZONTAL_ALIGNMENT_CENTER, 84, 14, outer_color)
