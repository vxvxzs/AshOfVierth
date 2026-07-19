class_name AshWitness
extends Node2D

const INTERACTION_RADIUS := 82.0
const DIALOGUE_RESOLVER = preload("res://scripts/dialogue/dialogue_resolver.gd")

var player_nearby := false

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	player_nearby = player != null and player.global_position.distance_to(global_position) <= INTERACTION_RADIUS
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby or _is_dialogue_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_open_dialogue()
	elif event is InputEventScreenTouch and event.pressed and event.position.distance_to(global_position) <= INTERACTION_RADIUS:
		_open_dialogue()

func _open_dialogue() -> void:
	var dialogue_panel := get_tree().get_first_node_in_group("dialogue_panel")
	if dialogue_panel != null:
		dialogue_panel.open_dialogue(DIALOGUE_RESOLVER.get_lines("ash_witness"))

func _is_dialogue_open() -> bool:
	var dialogue_panel := get_tree().get_first_node_in_group("dialogue_panel")
	return dialogue_panel != null and dialogue_panel.is_open()

func _draw() -> void:
	draw_circle(Vector2(0, -8), 13.0, Color("c4b6a0"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 10), Vector2(18, 10), Vector2(28, 42), Vector2(-28, 42)]), Color("4d3f44"))
	draw_line(Vector2(-16, 34), Vector2(-28, 56), Color("9f7752"), 4.0)
	if player_nearby and not _is_dialogue_open():
		var prompt := "Tap to speak" if _is_mobile_platform() else "E: Speak"
		draw_string(ThemeDB.fallback_font, Vector2(-56, -52), prompt, HORIZONTAL_ALIGNMENT_CENTER, 112, 16, Color("f2dcc0"))

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
