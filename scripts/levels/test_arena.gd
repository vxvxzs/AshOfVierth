extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const FLOOR_COLOR := Color("17212a")
const BORDER_COLOR := Color("61758a")
const GRID_COLOR := Color("24333f")
const RESPAWN_DELAY := 0.8
const ECHO_SCENE := preload("res://scenes/enemies/BrittleEcho.tscn")
const MEMORY_TRACE_SCENE := preload("res://scenes/world/MemoryTrace.tscn")
const TOTAL_ECHOES := 5
const LESSON_ECHOES := 2
const MAX_VISIBLE_MEMORY_TRACES := 3

@onready var player = $Player
@onready var ash_well = $AshWell
@onready var spirit = $Spirit
@onready var dialogue_panel = $DialoguePanel
@onready var mobile_controls = $MobileControls

var active_spawn_position := Vector2.ZERO
var respawn_time_left := -1.0
var shake_time_left := 0.0
var echoes_spawned := 0
var memory_traces: Array[Node2D] = []
var combat_lesson_complete := false

func _ready() -> void:
	player.died.connect(_on_player_died)
	ash_well.activated.connect(_on_checkpoint_activated)
	spirit.first_conversation_finished.connect(_on_spirit_met)
	mobile_controls.move_input_changed.connect(player.set_mobile_move_input)
	mobile_controls.attack_requested.connect(player.request_light_attack)
	mobile_controls.short_step_requested.connect(player.request_short_step)
	ash_well.activate()
	active_spawn_position = ash_well.get_spawn_position()
	ProgressionManager.set_objective("A brittle shape is moving nearby.")
	_spawn_next_echo()
	call_deferred("_show_combat_memory")
	queue_redraw()

func _show_combat_memory() -> void:
	await get_tree().create_timer(0.35).timeout
	dialogue_panel.dialogue_finished.connect(_on_combat_memory_closed, CONNECT_ONE_SHOT)
	dialogue_panel.open_dialogue([
		{ "speaker": "A faint voice", "text": "Do not run from it. It is repeating the last thing it knew." },
		{ "speaker": "A faint voice", "text": "Your hand already knows the answer. Let the blade remember." },
		{ "speaker": "A faint voice", "text": "When it reaches for you, answer before the memory closes." }
	])

func _on_combat_memory_closed() -> void:
	ProgressionManager.set_objective("Defeat the Brittle Echo.")

func _process(delta: float) -> void:
	if respawn_time_left >= 0.0:
		respawn_time_left -= delta
		if respawn_time_left <= 0.0:
			player.respawn(active_spawn_position)
			respawn_time_left = -1.0
	if shake_time_left > 0.0:
		shake_time_left -= delta
		position = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	else:
		position = Vector2.ZERO
	queue_redraw()

func _on_player_died() -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close_dialogue()
	_create_memory_trace(player.global_position)
	ProgressionManager.register_death()
	respawn_time_left = RESPAWN_DELAY
	shake_time_left = 0.16

func _on_checkpoint_activated(checkpoint) -> void:
	active_spawn_position = checkpoint.get_spawn_position()

func _spawn_next_echo() -> void:
	if echoes_spawned >= TOTAL_ECHOES:
		return
	echoes_spawned += 1
	var echo = ECHO_SCENE.instantiate()
	var marker: Marker2D = get_node("EchoSpawn%d" % echoes_spawned)
	echo.position = marker.position
	echo.defeated.connect(_on_echo_defeated)
	add_child(echo)

func _on_echo_defeated() -> void:
	await get_tree().create_timer(0.45).timeout
	if not combat_lesson_complete and ProgressionManager.echo_kills >= LESSON_ECHOES:
		ProgressionManager.set_objective("Follow the faint light and speak to the Spirit.")
		spirit.unlock_for_conversation()
		return
	if ProgressionManager.echo_kills < TOTAL_ECHOES:
		_spawn_next_echo()
	else:
		ProgressionManager.set_objective("3 Light received. Visit the Memory Shrine.")

func _on_spirit_met() -> void:
	if combat_lesson_complete:
		return
	combat_lesson_complete = true
	ProgressionManager.set_objective("Defeat the remaining Brittle Echoes.")
	_spawn_next_echo()

func _create_memory_trace(trace_position: Vector2) -> void:
	var trace: Node2D = MEMORY_TRACE_SCENE.instantiate()
	trace.position = trace_position
	trace.set_memory_number(ProgressionManager.death_count + 1)
	add_child(trace)
	memory_traces.append(trace)
	if memory_traces.size() > MAX_VISIBLE_MEMORY_TRACES:
		var oldest_trace: Node2D = memory_traces.pop_front()
		oldest_trace.queue_free()

func _draw() -> void:
	draw_rect(ARENA_RECT, FLOOR_COLOR, true)
	draw_rect(ARENA_RECT, BORDER_COLOR, false, 4.0)
	for x in range(int(ARENA_RECT.position.x) + 40, int(ARENA_RECT.end.x), 40):
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), GRID_COLOR, 1.0)
	for y in range(int(ARENA_RECT.position.y) + 40, int(ARENA_RECT.end.y), 40):
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), GRID_COLOR, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(100, 125), "ASH OF VIRETH — movement test", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d8e7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(100, 158), "WASD / Arrow Keys: move   |   J, Z or left mouse: attack", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9ab0c4"))
	if ProgressionManager.death_count > 0:
		draw_string(ThemeDB.fallback_font, Vector2(100, 190), "The arena remembers where you fell.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b1cee3"))
