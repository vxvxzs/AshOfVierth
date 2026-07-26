extends CanvasLayer

const INTRO_SCENE := "res://scenes/intro/IntroSequence.tscn"

var is_transitioning := false
var fade: ColorRect
var has_pending_spawn := false
var pending_spawn_position := Vector2.ZERO

func _ready() -> void:
	layer = 100
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	# Fade is visual only. It must never sit above the menu and consume taps.
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func start_new_game() -> void:
	ProgressionManager.reset_for_new_game()
	WorldState.reset_runtime_state()
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null:
		dialogue_manager.reset_runtime_state()
	var day_night_cycle := get_node_or_null("/root/DayNightCycle")
	if day_night_cycle != null:
		day_night_cycle.reset_clock()
	change_scene(INTRO_SCENE)

func change_scene(scene_path: String) -> void:
	if is_transitioning:
		return
	var scene_resource := load(scene_path)
	if not scene_resource is PackedScene:
		push_warning("SceneDirector rejected invalid scene: " + scene_path)
		has_pending_spawn = false
		return
	is_transitioning = true
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.35)
	await fade_out.finished
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error(
			"SceneDirector could not change to '%s' (error %d)."
			% [scene_path, change_error]
		)
		has_pending_spawn = false
		var recovery := create_tween()
		recovery.tween_property(fade, "color:a", 0.0, 0.2)
		await recovery.finished
		is_transitioning = false
		return
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.35)
	await fade_in.finished
	is_transitioning = false

func fade_to_black(duration: float = 0.35) -> void:
	var transition := create_tween()
	transition.tween_property(fade, "color:a", 1.0, duration)
	await transition.finished

func fade_from_black(duration: float = 0.35) -> void:
	var transition := create_tween()
	transition.tween_property(fade, "color:a", 0.0, duration)
	await transition.finished

func change_scene_with_spawn(scene_path: String, spawn_position: Vector2) -> void:
	has_pending_spawn = true
	pending_spawn_position = spawn_position
	change_scene(scene_path)

func consume_pending_spawn(default_position: Vector2) -> Vector2:
	if not has_pending_spawn:
		return default_position
	has_pending_spawn = false
	return pending_spawn_position
