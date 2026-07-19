class_name Spirit
extends Node2D

const INTERACTION_RADIUS := 82.0
const SPIRIT_COLOR := Color("9cecf0")
const PROMPT_COLOR := Color("d8ffff")

signal first_conversation_finished

var player_nearby := false
var pulse_time := 0.0
var available := false

func _process(delta: float) -> void:
	pulse_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	player_nearby = player != null and player.global_position.distance_to(global_position) <= INTERACTION_RADIUS
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not available or not player_nearby or _is_dialogue_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_start_conversation()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed and event.position.distance_to(global_position) <= INTERACTION_RADIUS:
		_start_conversation()
		get_viewport().set_input_as_handled()

func _start_conversation() -> void:
	var dialogue_panel := get_tree().get_first_node_in_group("dialogue_panel")
	if dialogue_panel == null:
		return
	var is_first_conversation := not ProgressionManager.has_story_flag(&"spirit_met")
	if is_first_conversation:
		dialogue_panel.dialogue_finished.connect(_on_first_conversation_closed, CONNECT_ONE_SHOT)
	dialogue_panel.open_dialogue(_get_dialogue_lines())
	ProgressionManager.set_story_flag(&"spirit_met")

func unlock_for_conversation() -> void:
	available = true
	queue_redraw()

func _on_first_conversation_closed() -> void:
	first_conversation_finished.emit()

func _get_dialogue_lines() -> Array[Dictionary]:
	if not ProgressionManager.has_story_flag(&"spirit_met"):
		if ProgressionManager.death_count > 0:
			return [
				{ "speaker": "Spirit", "text": "You came back." },
				{ "speaker": "Spirit", "text": "The well kept the shape of your fall. I do not think it should be able to do that." },
				{ "speaker": "Spirit", "text": "I know the shape of a sword. I do not know why." }
			]
		return [
			{ "speaker": "Spirit", "text": "Wait. Do not move the shard." },
			{ "speaker": "Spirit", "text": "No—move it. I think that is why I am here." },
			{ "speaker": "Spirit", "text": "I know the shape of a sword. I do not know why." }
		]
	if ProgressionManager.death_count == 0:
		return [{ "speaker": "Spirit", "text": "The well is listening." }]
	if ProgressionManager.death_count < 4:
		return [{ "speaker": "Spirit", "text": "I remembered you falling before I saw you wake." }]
	return [{ "speaker": "Spirit", "text": "There are too many versions of you here. Please do not look at them too long." }]

func _is_dialogue_open() -> bool:
	var dialogue_panel := get_tree().get_first_node_in_group("dialogue_panel")
	return dialogue_panel != null and dialogue_panel.is_open()

func _draw() -> void:
	var pulse := sin(pulse_time * 2.5) * 3.0
	draw_circle(Vector2(0, -4), 27.0 + pulse, Color(SPIRIT_COLOR, 0.08))
	draw_circle(Vector2(0, -4), 15.0 + pulse * 0.25, Color(SPIRIT_COLOR, 0.20))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(14, -4), Vector2(5, 23), Vector2(0, 32), Vector2(-6, 23), Vector2(-14, -4)]), SPIRIT_COLOR)
	draw_circle(Vector2(0, -3), 8.0, Color("2e5664"))
	if available and player_nearby and not _is_dialogue_open():
		var prompt := "Tap the Spirit" if _is_mobile_platform() else "E: Speak"
		draw_string(ThemeDB.fallback_font, Vector2(-56, -54), prompt, HORIZONTAL_ALIGNMENT_CENTER, 112, 16, PROMPT_COLOR)

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
