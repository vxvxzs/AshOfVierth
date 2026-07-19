class_name RegionExit
extends Node2D

@export_file("*.tscn") var target_scene_path := ""
@export var required_ability: StringName = &"short_step"
@export var label_text := "Enter Ash Forest"

const INTERACTION_RADIUS := 76.0

var player_nearby := false

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	player_nearby = player != null and player.global_position.distance_to(global_position) <= INTERACTION_RADIUS
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_available() or not player_nearby:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_enter_region()
	elif event is InputEventScreenTouch and event.pressed and event.position.distance_to(global_position) <= INTERACTION_RADIUS:
		_enter_region()

func _is_available() -> bool:
	return required_ability == &"" or ProgressionManager.is_ability_unlocked(required_ability)

func _enter_region() -> void:
	if not target_scene_path.is_empty():
		get_tree().change_scene_to_file(target_scene_path)

func _draw() -> void:
	var active := _is_available()
	var color := Color("d4ad68") if active else Color("45515c")
	draw_circle(Vector2.ZERO, 34.0, Color(color, 0.14))
	draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 24, color, 3.0, true)
	draw_line(Vector2(-12, 0), Vector2(12, 0), color, 3.0)
	draw_line(Vector2(6, -7), Vector2(13, 0), color, 3.0)
	draw_line(Vector2(6, 7), Vector2(13, 0), color, 3.0)
	if active and player_nearby:
		var prompt := "Tap to enter" if _is_mobile_platform() else "E: %s" % label_text
		draw_string(ThemeDB.fallback_font, Vector2(-82, -50), prompt, HORIZONTAL_ALIGNMENT_CENTER, 164, 16, Color("f6e2ba"))
	elif not active:
		draw_string(ThemeDB.fallback_font, Vector2(-72, -50), "Awaken Short Step", HORIZONTAL_ALIGNMENT_CENTER, 144, 14, Color("8995a2"))

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
