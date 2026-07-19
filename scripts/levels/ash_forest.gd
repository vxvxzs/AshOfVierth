extends Node2D

const FOREST_RECT := Rect2(60, 72, 1160, 576)
const RESPAWN_DELAY := 0.8
const MEMORY_TRACE_SCENE := preload("res://scenes/world/MemoryTrace.tscn")
const MAX_VISIBLE_MEMORY_TRACES := 3

@onready var player = $Player
@onready var anchor = $ForestAnchor
@onready var dialogue_panel = $DialoguePanel
@onready var mobile_controls = $MobileControls
@onready var boss = $AshWarden
@onready var boss_hurtbox: CollisionShape2D = $AshWarden/Hurtbox/CollisionShape2D

var active_spawn_position := Vector2.ZERO
var respawn_time_left := -1.0
var pre_boss_enemies_remaining := 3
var memory_traces: Array[Node2D] = []

func _ready() -> void:
	player.died.connect(_on_player_died)
	anchor.activated.connect(_on_anchor_activated)
	mobile_controls.move_input_changed.connect(player.set_mobile_move_input)
	mobile_controls.attack_requested.connect(player.request_light_attack)
	mobile_controls.short_step_requested.connect(player.request_short_step)
	$AshHound.defeated.connect(_on_preboss_enemy_defeated)
	$RootWarden.defeated.connect(_on_preboss_enemy_defeated)
	$BrittleEcho.defeated.connect(_on_preboss_enemy_defeated)
	boss.defeated.connect(_on_boss_defeated)
	boss.enraged.connect(_on_boss_enraged)
	boss.hide()
	boss.set_physics_process(false)
	boss_hurtbox.set_deferred("disabled", true)
	$TestHUD.set_combat_counter_visible(false)
	anchor.activate()
	active_spawn_position = WorldState.current_anchor_position
	WorldState.set_flag(&"ash_forest_entered")
	ProgressionManager.set_objective("Clear the path through Ash Forest.")
	queue_redraw()

func _process(delta: float) -> void:
	if respawn_time_left < 0.0:
		return
	respawn_time_left -= delta
	if respawn_time_left <= 0.0:
		player.respawn(active_spawn_position)
		respawn_time_left = -1.0

func _on_player_died() -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close_dialogue()
	WorldState.register_death()
	WorldState.set_flag(&"ash_forest_death_seen")
	_create_memory_trace(player.global_position)
	respawn_time_left = RESPAWN_DELAY
	queue_redraw()

func _on_anchor_activated(_checkpoint) -> void:
	active_spawn_position = WorldState.current_anchor_position

func _on_preboss_enemy_defeated() -> void:
	pre_boss_enemies_remaining -= 1
	if pre_boss_enemies_remaining > 0:
		return
	boss.show()
	boss.set_physics_process(true)
	boss_hurtbox.set_deferred("disabled", false)
	ProgressionManager.set_objective("Defeat the Ash Warden.")
	dialogue_panel.open_dialogue([
		{ "speaker": "Spirit", "text": "The roots are moving. Something kept the fire alive." },
		{ "speaker": "Spirit", "text": "Do not let it force you into the ash." }
	])

func _on_boss_enraged() -> void:
	ProgressionManager.set_objective("The Ash Warden is breaking apart. Keep moving.")

func _on_boss_defeated() -> void:
	WorldState.set_flag(&"ash_forest_cleared")
	ProgressionManager.set_objective("Ash Forest cleared.")
	dialogue_panel.open_dialogue([
		{ "speaker": "Spirit", "text": "It was not guarding the fire. It was holding it together." },
		{ "speaker": "Spirit", "text": "I remember giving an order here. I do not remember to whom." }
	])
	queue_redraw()

func _create_memory_trace(trace_position: Vector2) -> void:
	var trace: Node2D = MEMORY_TRACE_SCENE.instantiate()
	trace.position = trace_position
	trace.set_memory_number(WorldState.death_count)
	add_child(trace)
	memory_traces.append(trace)
	if memory_traces.size() > MAX_VISIBLE_MEMORY_TRACES:
		memory_traces.pop_front().queue_free()

func _draw() -> void:
	var debt_seen := WorldState.has_flag(&"ash_forest_death_seen")
	var floor_color := Color("263027") if not debt_seen else Color("2e2630")
	draw_rect(FOREST_RECT, floor_color, true)
	draw_rect(FOREST_RECT, Color("7f8868"), false, 4.0)
	_draw_ash_path()
	_draw_trees(debt_seen)
	if debt_seen:
		_draw_reconstruction_scars()
	draw_string(ThemeDB.fallback_font, Vector2(92, 118), "ASH FOREST", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e8dfbe"))
	if WorldState.has_flag(&"ash_forest_cleared"):
		draw_string(ThemeDB.fallback_font, Vector2(92, 148), "The fire has no keeper now.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e7b986"))

func _draw_ash_path() -> void:
	var path_points := PackedVector2Array([
		Vector2(90, 402), Vector2(290, 388), Vector2(470, 428), Vector2(650, 372),
		Vector2(830, 334), Vector2(1020, 360), Vector2(1190, 326)
	])
	for index in range(path_points.size() - 1):
		draw_line(path_points[index], path_points[index + 1], Color("697064"), 72.0, true)
		draw_line(path_points[index], path_points[index + 1], Color("9a8c72"), 34.0, true)

func _draw_trees(debt_seen: bool) -> void:
	var tree_positions := [
		Vector2(125, 190), Vector2(205, 272), Vector2(290, 145), Vector2(386, 250), Vector2(470, 168),
		Vector2(560, 260), Vector2(680, 150), Vector2(756, 244), Vector2(870, 154), Vector2(966, 238),
		Vector2(1090, 180), Vector2(1155, 274), Vector2(188, 555), Vector2(318, 530), Vector2(514, 548),
		Vector2(720, 542), Vector2(890, 548), Vector2(1080, 528)
	]
	for position in tree_positions:
		var canopy_color := Color("3e4d3b") if not debt_seen else Color("4d394a")
		draw_circle(position, 34.0, canopy_color)
		draw_circle(position + Vector2(16, -10), 24.0, canopy_color.lightened(0.08))
		draw_line(position + Vector2(0, 18), position + Vector2(0, 52), Color("5b4939"), 8.0)

func _draw_reconstruction_scars() -> void:
	for position in [Vector2(405, 350), Vector2(600, 465), Vector2(790, 290), Vector2(1010, 440)]:
		draw_arc(position, 28.0, 0.0, TAU, 18, Color("be647b", 0.72), 2.0, true)
		draw_circle(position, 6.0, Color("d38c9e", 0.8))
