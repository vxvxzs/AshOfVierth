extends Node2D

const INTERACTION_RADIUS := 72.0
const SHRINE_COLOR := Color("8ee6e8")

var player_nearby := false

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	player_nearby = player != null and player.global_position.distance_to(global_position) <= INTERACTION_RADIUS
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_open_panel()
	elif event is InputEventScreenTouch and event.pressed and event.position.distance_to(global_position) <= INTERACTION_RADIUS:
		_open_panel()

func _open_panel() -> void:
	var panel := get_tree().get_first_node_in_group("skill_panel")
	if panel != null:
		panel.open_panel()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 28.0, Color(SHRINE_COLOR, 0.20))
	draw_circle(Vector2.ZERO, 18.0, SHRINE_COLOR)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 20, Color("d8ffff"), 2.0, true)
	if player_nearby:
		var prompt := "Tap the Shrine" if _is_mobile_platform() else "E: Memory Shrine"
		draw_string(ThemeDB.fallback_font, Vector2(-68, -46), prompt, HORIZONTAL_ALIGNMENT_CENTER, 136, 16, Color("d8ffff"))

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
