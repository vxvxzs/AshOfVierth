extends Node2D

@onready var player: Player = $Player

func _ready() -> void:
	player.set_movement_enabled(true)
	player.abilities.set_combat_enabled(false)
	player.abilities.set_step_enabled(false)
	queue_redraw()

func _draw() -> void:
	# Intentional placeholder: this establishes scale and mood until the actual
	# city tileset is ready, without pretending to be final environment art.
	draw_rect(Rect2(0, 0, 1280, 720), Color("182532"))
	draw_rect(Rect2(0, 330, 1280, 390), Color("5c584d"))
	draw_rect(Rect2(0, 410, 1280, 310), Color("756b5a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 360), Vector2(230, 290), Vector2(440, 316), Vector2(690, 230),
		Vector2(920, 290), Vector2(1280, 250), Vector2(1280, 430), Vector2(0, 430)
	]), Color("2d3740"))
	# Distant wall and a closed gate.
	draw_rect(Rect2(170, 245, 940, 125), Color("40454a"))
	draw_rect(Rect2(490, 205, 100, 165), Color("343a40"))
	draw_rect(Rect2(790, 205, 100, 165), Color("343a40"))
	draw_rect(Rect2(600, 270, 80, 100), Color("1b2025"))
	draw_line(Vector2(640, 270), Vector2(640, 370), Color("647075"), 3.0)
	# Road leading to the closed gate.
	draw_colored_polygon(PackedVector2Array([
		Vector2(380, 720), Vector2(900, 720), Vector2(700, 370), Vector2(580, 370)
	]), Color("9a8a6b"))
	draw_line(Vector2(640, 720), Vector2(640, 370), Color("c6b07d"), 3.0)
