@tool
class_name ReturnJourney
extends Node

## Cinematic controller. Route points live only in Path2D nodes in the scene.
## Edit the three visible curves directly in Godot; this code only animates them.

const FADE_DURATION := 0.20
const EMPTY_FOREST_DURATION := 1.65
const WALK_MAIN_PROGRESS := 0.8
const WALK_MAIN_DURATION := 18.0
const WALK_FINAL_DURATION := 6.0
const WALK_DURATION := WALK_MAIN_DURATION + WALK_FINAL_DURATION
const FADE_LEAD_DURATION := 0.95
const FIRST_CUTSCENE_SCENE := "res://scenes/cutscenes/FirstCutscene.tscn"

const FOREST_SHOTS: Array[Texture2D] = [
	preload("res://assets/art/environment/forest_intro/forest_return_01.png"),
	preload("res://assets/art/environment/forest_intro/forest_return_02.png"),
	preload("res://assets/art/environment/forest_intro/forest_return_03.png")
]

@export_category("Editor Preview")
@export_enum("Shot 1 - Alder Pass", "Shot 2 - Old Forest Road", "Shot 3 - Last Mile") var editor_preview_shot := 0:
	set(value):
		editor_preview_shot = clampi(value, 0, FOREST_SHOTS.size() - 1)
		if is_inside_tree():
			_apply_editor_preview()

@export_range(0.0, 1.0, 0.01) var editor_preview_progress := 0.35:
	set(value):
		editor_preview_progress = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			_apply_editor_preview()

@export_category("Path Polish")
@export var smooth_drawn_paths := false:
	set(value):
		if not value:
			return
		smooth_drawn_paths = false
		if is_inside_tree():
			_smooth_existing_paths()

@export_range(0.05, 0.5, 0.01) var path_handle_strength := 0.22

@export_category("Cinematic Direction Overrides")
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_1_start_direction := 2
@export_range(0.0, 1.0, 0.01) var shot_1_middle_at := 0.34
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_1_middle_direction := 2
@export_range(0.0, 1.0, 0.01) var shot_1_end_at := 0.72
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_1_end_direction := 2

@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_2_start_direction := 8
@export_range(0.0, 1.0, 0.01) var shot_2_middle_at := 0.36
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_2_middle_direction := 8
@export_range(0.0, 1.0, 0.01) var shot_2_end_at := 0.74
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_2_end_direction := 8

@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_3_start_direction := 2
@export_range(0.0, 1.0, 0.01) var shot_3_middle_at := 0.36
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_3_middle_direction := 2
@export_range(0.0, 1.0, 0.01) var shot_3_end_at := 0.74
@export_enum("Auto", "North", "North East", "East", "South East", "South", "South West", "West", "North West") var shot_3_end_direction := 2

@export_group("Shot 1 - Alder Pass")
@export var start_scale: float = 1.5
@export var end_scale: float = 0.7

@export_group("Shot 2 - Old Forest Road")
@export var shot_2_start_scale: float = 1.4
@export var shot_2_end_scale: float = 0.82

@export_group("Shot 3 - Last Mile")
@export var shot_3_start_scale: float = 1.45
@export var shot_3_end_scale: float = 0.75

@onready var background: TextureRect = $CinematicStage/Background
@onready var animated_backgrounds: Array[VideoStreamPlayer] = [
	$CinematicStage/AnimatedBackgroundShot01,
	$CinematicStage/AnimatedBackgroundShot02,
	$CinematicStage/AnimatedBackgroundShot03
]
@onready var foreground_shot_01: TextureRect = $CinematicStage/ForegroundShot01
@onready var foreground_shot_02: TextureRect = $CinematicStage/ForegroundShot02
@onready var shot_follows: Array[PathFollow2D] = [
	$CinematicStage/ShotPaths/ShotPath01/Follow,
	$CinematicStage/ShotPaths/ShotPath02/Follow,
	$CinematicStage/ShotPaths/ShotPath03/Follow
]
@onready var player: Player = $CinematicStage/ShotPaths/ShotPath01/Follow/Player
@onready var cinematic_camera: Camera2D = get_node_or_null("CinematicCamera") as Camera2D
@onready var narration: NarrationOverlay = $NarrationOverlay
@onready var cinematic_ui: CanvasLayer = $CinematicUI
@onready var fade: ColorRect = $CinematicUI/Fade
@onready var location_label: Label = $CinematicUI/LocationLabel
@onready var ending_label: Label = $CinematicUI/EndingLabel

var _active_follow: PathFollow2D
var _previous_path_position := Vector2.ZERO
var _walking_cinematic := false

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_preview")
		return
	player.set_movement_enabled(false)
	player.abilities.set_combat_enabled(false)
	player.abilities.set_step_enabled(false)
	# The editor may save this CanvasLayer as hidden. It owns the fade, so the
	# cinematic always enables it explicitly instead of relying on scene state.
	cinematic_ui.show()
	_set_cinematic_camera_enabled(false)
	fade.color.a = 1.0
	ending_label.hide()
	call_deferred("_play_return_journey")

func _apply_editor_preview() -> void:
	if background == null or player == null:
		return
	var preview_paths: Array[NodePath] = [
		NodePath("CinematicStage/ShotPaths/ShotPath01/Follow"),
		NodePath("CinematicStage/ShotPaths/ShotPath02/Follow"),
		NodePath("CinematicStage/ShotPaths/ShotPath03/Follow")
	]
	if editor_preview_shot < 0 or editor_preview_shot >= preview_paths.size():
		return
	var follow := get_node_or_null(preview_paths[editor_preview_shot]) as PathFollow2D
	if follow == null:
		# Inspector setters can run while Godot is still rebuilding the scene tree.
		# The next normal editor refresh will apply the preview safely.
		return
	var path := follow.get_parent() as Path2D
	if (
		path == null
		or not follow.is_inside_tree()
		or not path.is_inside_tree()
		or path.curve == null
		or path.curve.point_count < 2
	):
		# Tool setters can also fire between attaching PathFollow2D and its
		# Path2D parent to the edited scene. Setting progress in that brief
		# window makes Godot report an editor-only error.
		return
	# Keep the editor preview still: a static image is much easier to line up
	# with manually drawn Path2D points than a moving video frame.
	background.show()
	for video in animated_backgrounds:
		video.hide()
	background.texture = FOREST_SHOTS[editor_preview_shot]
	_set_foreground_for_shot(editor_preview_shot)
	_set_cinematic_camera_enabled(false)
	follow.progress_ratio = editor_preview_progress
	player.global_position = follow.global_position
	player.scale = Vector2.ONE * _preview_scale(editor_preview_shot, editor_preview_progress)
	player.show()
	var preview_direction := _get_override_direction(editor_preview_shot, editor_preview_progress)
	if preview_direction == Vector2.ZERO:
		preview_direction = Vector2(1.0, -1.0)
	player.set_cinematic_walking(true, preview_direction)

func _preview_scale(shot_index: int, progress: float) -> float:
	match shot_index:
		0:
			return lerpf(start_scale, end_scale, progress)
		1:
			return lerpf(shot_2_start_scale, shot_2_end_scale, progress)
		_:
			return lerpf(shot_3_start_scale, shot_3_end_scale, progress)

func _get_cinematic_blur(shot_index: int, progress: float) -> float:
	# Keep Iven crisp for most of the walk; soften him only toward the distant
	# end of the painted shot. Shot 2 remains comparatively close to camera.
	var maximum_blur := 0.9 if shot_index == 1 else 1.25
	var delayed_progress := clampf((progress - 0.52) / 0.48, 0.0, 1.0)
	return lerpf(0.0, maximum_blur, delayed_progress * delayed_progress)

func _set_foreground_for_shot(shot_index: int) -> void:
	foreground_shot_01.visible = shot_index == 0
	foreground_shot_02.visible = shot_index == 1

func _set_background_for_shot(shot_index: int) -> void:
	# Keep the still image below the video. It is a safe fallback if a decoder
	# drops a frame of an ambient clip on a mobile device.
	background.visible = true
	background.texture = FOREST_SHOTS[shot_index]
	for video_index in animated_backgrounds.size():
		var video := animated_backgrounds[video_index]
		var is_active := video_index == shot_index
		video.visible = is_active
		if is_active:
			video.stop()
			video.stream_position = 0.0
			video.play()
		else:
			video.stop()

## Keeps every hand-placed point exactly where it is and adds symmetric Bezier
## handles between them. Tick "Smooth Drawn Paths" on ReturnJourney in the
## Inspector after changing points; the tick resets itself when finished.
func _smooth_existing_paths() -> void:
	for path: Path2D in [
		$CinematicStage/ShotPaths/ShotPath01,
		$CinematicStage/ShotPaths/ShotPath02,
		$CinematicStage/ShotPaths/ShotPath03
	]:
		var curve := path.curve
		if curve == null or curve.point_count < 2:
			continue
		for point_index in curve.point_count:
			var current := curve.get_point_position(point_index)
			if point_index == 0:
				var next := curve.get_point_position(1)
				curve.set_point_in(point_index, Vector2.ZERO)
				curve.set_point_out(point_index, (next - current) * path_handle_strength)
			elif point_index == curve.point_count - 1:
				var previous := curve.get_point_position(point_index - 1)
				curve.set_point_in(point_index, (previous - current) * path_handle_strength)
				curve.set_point_out(point_index, Vector2.ZERO)
			else:
				var previous := curve.get_point_position(point_index - 1)
				var next := curve.get_point_position(point_index + 1)
				var tangent := (next - previous) * path_handle_strength
				curve.set_point_in(point_index, -tangent)
				curve.set_point_out(point_index, tangent)
		curve.emit_changed()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _walking_cinematic or _active_follow == null:
		return
	if cinematic_camera != null:
		# The camera is positioned before the player appears, then follows the
		# path exactly. This avoids a hard camera jump during the reveal.
		cinematic_camera.global_position = _active_follow.global_position
	player.set_cinematic_distance_blur(_get_cinematic_blur(shot_follows.find(_active_follow), _active_follow.progress_ratio))
	var movement_vector := _active_follow.global_position - _previous_path_position
	var manual_direction := _get_override_direction(shot_follows.find(_active_follow), _active_follow.progress_ratio)
	if manual_direction != Vector2.ZERO:
		player.set_cinematic_walking(true, manual_direction)
	elif movement_vector.length_squared() > 0.01:
		player.set_cinematic_walking(true, movement_vector.normalized())
	_previous_path_position = _active_follow.global_position

func _get_override_direction(shot_index: int, progress: float) -> Vector2:
	var direction_id := 0
	match shot_index:
		0:
			direction_id = shot_1_start_direction if progress < shot_1_middle_at else shot_1_middle_direction if progress < shot_1_end_at else shot_1_end_direction
		1:
			direction_id = shot_2_start_direction if progress < shot_2_middle_at else shot_2_middle_direction if progress < shot_2_end_at else shot_2_end_direction
		2:
			direction_id = shot_3_start_direction if progress < shot_3_middle_at else shot_3_middle_direction if progress < shot_3_end_at else shot_3_end_direction
	return _direction_from_id(direction_id)

func _direction_from_id(direction_id: int) -> Vector2:
	match direction_id:
		1: return Vector2.UP
		2: return Vector2(1.0, -1.0).normalized()
		3: return Vector2.RIGHT
		4: return Vector2(1.0, 1.0).normalized()
		5: return Vector2.DOWN
		6: return Vector2(-1.0, 1.0).normalized()
		7: return Vector2.LEFT
		8: return Vector2(-1.0, -1.0).normalized()
		_: return Vector2.ZERO

func _play_return_journey() -> void:
	await _play_shot(0, "ALDER PASS", start_scale, end_scale, [
		{ "speaker": "Iven", "text": "The road into Vierth always smelled of wet bark and hearth smoke. Three years away, and I still knew it before I saw the trees.", "duration": 7.0 },
		{ "speaker": "Iven", "text": "I carried parcels through half the valley, but no road ever felt as familiar as this one.", "duration": 5.7 }
	])
	await _play_shot(1, "THE OLD FOREST ROAD", shot_2_start_scale, shot_2_end_scale, [
		{ "speaker": "Iven", "text": "I used to hurry here. Home meant warm bread, river water under the bridge, and somebody asking why I was late.", "duration": 6.7 },
		{ "speaker": "Iven", "text": "Now I am walking slowly on purpose. I want the road to last a little longer.", "duration": 5.8 }
	])
	await _play_shot(2, "THE LAST MILE", shot_3_start_scale, shot_3_end_scale, [
		{ "speaker": "Iven", "text": "Vierth should be beyond these trees. I can almost picture the market square as it was the morning I left.", "duration": 6.7 },
		{ "speaker": "Iven", "text": "I have rehearsed coming home for three years. Somehow, I never imagined it would feel this quiet.", "duration": 6.2 }
	])
	_walking_cinematic = false
	player.hide()
	SceneDirector.change_scene(FIRST_CUTSCENE_SCENE)

func _play_shot(shot_index: int, location: String, near_scale: float, far_scale: float, lines: Array) -> void:
	_active_follow = shot_follows[shot_index]
	_set_background_for_shot(shot_index)
	_set_foreground_for_shot(shot_index)
	_set_cinematic_camera_enabled(false)
	if player.get_parent() != _active_follow:
		player.reparent(_active_follow, false)
	player.position = Vector2.ZERO
	player.hide()
	player.scale = Vector2.ONE * near_scale
	player.set_cinematic_distance_blur(0.0)
	_active_follow.progress_ratio = 0.0
	_previous_path_position = _active_follow.global_position
	if cinematic_camera != null:
		# Frame the empty establishing shot exactly as the player will be framed.
		# The reveal is therefore seamless instead of snapping to a new camera.
		cinematic_camera.global_position = _active_follow.global_position
		_set_cinematic_camera_enabled(true)
	_show_location(location)
	await _fade_from_black()
	await get_tree().create_timer(EMPTY_FOREST_DURATION).timeout
	player.show()
	_walking_cinematic = true
	player.set_cinematic_walking(true, _get_override_direction(shot_index, 0.0))
	narration.play_sequence(lines)
	var movement_tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	movement_tween.tween_property(_active_follow, "progress_ratio", WALK_MAIN_PROGRESS, WALK_MAIN_DURATION)
	movement_tween.tween_property(_active_follow, "progress_ratio", 1.0, WALK_FINAL_DURATION)
	var scale_tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	scale_tween.tween_property(player, "scale", Vector2.ONE * lerpf(near_scale, far_scale, WALK_MAIN_PROGRESS), WALK_MAIN_DURATION)
	scale_tween.tween_property(player, "scale", Vector2.ONE * far_scale, WALK_FINAL_DURATION)
	# Start the outgoing fade just before the route ends. We intentionally do
	# not wait for a Tween signal here: the next shot must always be entered
	# once the screen is black, even if a tween is interrupted by a scene edit.
	await get_tree().create_timer(WALK_DURATION - FADE_LEAD_DURATION).timeout
	await _fade_to_black()
	movement_tween.kill()
	scale_tween.kill()
	_active_follow.progress_ratio = 1.0
	player.scale = Vector2.ONE * far_scale

func _set_cinematic_camera_enabled(is_enabled: bool) -> void:
	if cinematic_camera != null:
		cinematic_camera.enabled = is_enabled

func _show_location(location: String) -> void:
	location_label.text = location
	location_label.modulate.a = 0.0
	var label_tween := create_tween()
	label_tween.tween_property(location_label, "modulate:a", 1.0, 0.45)
	label_tween.tween_interval(1.7)
	label_tween.tween_property(location_label, "modulate:a", 0.0, 0.45)

func _fade_to_black() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_DURATION)
	await tween.finished

func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_DURATION)
	await tween.finished
