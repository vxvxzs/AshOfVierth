@tool
class_name Player
extends CharacterBody2D

const BODY_RADIUS := 18.0
const BODY_COLOR := Color("d8e7ff")
const CLOAK_COLOR := Color("3f668a")
const DASH_COLOR := Color("87d7ff")
const ATTACK_COLOR := Color("f4cf8c")
const CLEAN_CLOAK_COLOR := Color("3f668a")
const DIRTY_CLOAK_COLOR := Color("4b4844")
const IVEN_ANIMATION_ROOT := "res://assets/art/characters/iven/Full-body_character_sprite_of_Iven/animations"
const WALK_FRAME_COUNT := 6
const IDLE_FRAME_COUNT := 4
const CINEMATIC_BLUR_SHADER := preload("res://shaders/cinematic_distance_blur.gdshader")

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var abilities: PlayerAbilities = $Abilities
@onready var health = $Health
@onready var defense = $Defense
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing_direction := Vector2.DOWN
var mobile_move_input := Vector2.ZERO
var movement_enabled := true
var visual_variant: StringName = &"clean"
var cinematic_walking := false
var cinematic_direction := Vector2.RIGHT
var _cinematic_blur_material: ShaderMaterial

signal died
signal damaged(source)

func _ready() -> void:
	_build_iven_sprite_frames()
	if Engine.is_editor_hint():
		set_cinematic_walking(true, Vector2(1.0, -1.0))
		return
	_ensure_movement_input_actions()
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	health.died.connect(_on_health_depleted)
	if ProgressionManager.is_ability_unlocked(&"short_step"):
		abilities.unlock_short_step()

func _ensure_movement_input_actions() -> void:
	_register_movement_action(&"move_left", [KEY_A, KEY_LEFT])
	_register_movement_action(&"move_right", [KEY_D, KEY_RIGHT])
	_register_movement_action(&"move_up", [KEY_W, KEY_UP])
	_register_movement_action(&"move_down", [KEY_S, KEY_DOWN])

func _register_movement_action(action_id: StringName, keys: Array) -> void:
	if InputMap.has_action(action_id):
		return
	InputMap.add_action(action_id)
	for keycode in keys:
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_id, event)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		if cinematic_walking:
			_update_sprite(cinematic_direction)
		return
	if health.is_dead():
		return
	var input_direction := Vector2.ZERO if _is_dialogue_open() or not movement_enabled else _read_movement_input()
	if input_direction != Vector2.ZERO:
		facing_direction = input_direction

	abilities.tick(delta)
	health.tick(delta)
	defense.tick(delta)
	combat.tick(delta)
	combat.update_hitbox_position(facing_direction)

	if abilities.is_dashing():
		velocity = abilities.get_dash_velocity()
	else:
		movement.update_velocity(self, input_direction, combat.get_move_speed_multiplier(), delta)

	move_and_slide()
	_update_sprite(cinematic_direction if cinematic_walking else input_direction)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _is_dialogue_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			request_short_step()
		elif event.keycode == KEY_J or event.keycode == KEY_Z:
			request_light_attack()
		elif event.keycode == KEY_K:
			request_parry()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_light_attack()

func set_mobile_move_input(new_direction: Vector2) -> void:
	mobile_move_input = new_direction.limit_length(1.0)

func request_light_attack() -> void:
	if abilities.is_combat_enabled() and not _is_dialogue_open() and not health.is_dead():
		combat.try_light_attack()

func request_short_step() -> void:
	if movement_enabled and not _is_dialogue_open() and not health.is_dead():
		abilities.try_dash(_read_movement_input(), facing_direction)

func request_parry() -> void:
	if abilities.is_combat_enabled() and not _is_dialogue_open() and not health.is_dead():
		defense.try_parry()

func request_interaction() -> void:
	if _is_dialogue_open() or health.is_dead():
		return
	var closest_interactable: Node2D
	var closest_distance := INF
	for candidate_node in get_tree().get_nodes_in_group(&"player_interactable"):
		var candidate := candidate_node as Node2D
		if candidate == null or not candidate.has_method("can_interact"):
			continue
		if not bool(candidate.call("can_interact", self)):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < closest_distance:
			closest_interactable = candidate
			closest_distance = distance
	if closest_interactable != null:
		closest_interactable.call("interact", self)

func _read_movement_input() -> Vector2:
	if mobile_move_input != Vector2.ZERO:
		return mobile_move_input
	return _read_keyboard_direction()

func _read_keyboard_direction() -> Vector2:
	var mapped_direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if mapped_direction != Vector2.ZERO:
		return mapped_direction
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	return direction.normalized()

func _is_dialogue_open() -> bool:
	var dialogue_panel := get_tree().get_first_node_in_group("dialogue_panel")
	return dialogue_panel != null and dialogue_panel.is_open()

func is_invulnerable() -> bool:
	return abilities.is_invulnerable() or health.is_invulnerable()

func is_parrying() -> bool:
	return defense.is_parrying()

func unlock_short_step() -> void:
	abilities.unlock_short_step()

func set_movement_enabled(is_enabled: bool) -> void:
	movement_enabled = is_enabled
	if not movement_enabled:
		velocity = Vector2.ZERO

func set_cinematic_walking(is_walking: bool, direction: Vector2 = Vector2.RIGHT) -> void:
	cinematic_walking = is_walking
	cinematic_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	if cinematic_walking:
		facing_direction = cinematic_direction
	_update_sprite(cinematic_direction if cinematic_walking else Vector2.ZERO)

func set_cinematic_distance_blur(blur_radius: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cinematic_blur_material == null:
		_cinematic_blur_material = ShaderMaterial.new()
		_cinematic_blur_material.shader = CINEMATIC_BLUR_SHADER
		animated_sprite.material = _cinematic_blur_material
	_cinematic_blur_material.set_shader_parameter("blur_radius", clampf(blur_radius, 0.0, 2.0))

func set_visual_variant(new_variant: StringName) -> void:
	visual_variant = new_variant
	queue_redraw()

func _on_ability_unlocked(ability_id: StringName) -> void:
	if ability_id == &"short_step":
		unlock_short_step()

func take_damage(amount: int, source = null) -> bool:
	if is_invulnerable():
		return false
	damaged.emit(source)
	var took_damage: bool = health.take_damage(amount)
	queue_redraw()
	return took_damage

func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health.restore_full()
	show()
	queue_redraw()

func _on_health_depleted() -> void:
	velocity = Vector2.ZERO
	hide()
	died.emit()

func _update_sprite(input_direction: Vector2) -> void:
	if animated_sprite.sprite_frames == null:
		return
	# Component scripts are editor placeholders while this scene is being previewed.
	# Do not ask them about combat state outside a running game.
	var is_dashing := false
	if not Engine.is_editor_hint():
		is_dashing = abilities.is_dashing()
	var direction := abilities.get_dash_direction() if is_dashing else facing_direction
	var animation := _directional_animation_name(direction, "walk")
	var is_moving := input_direction != Vector2.ZERO or is_dashing or cinematic_walking
	if is_moving:
		if animated_sprite.animation != animation:
			animated_sprite.play(animation)
		if not animated_sprite.is_playing():
			animated_sprite.play(animation)
	else:
		var idle_animation := _directional_animation_name(facing_direction, "idle")
		if animated_sprite.animation != idle_animation:
			animated_sprite.play(idle_animation)
		elif not animated_sprite.is_playing():
			animated_sprite.play(idle_animation)

func _build_iven_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	_add_directional_frames(frames, "walk", "Walk", WALK_FRAME_COUNT, 8.0)
	_add_directional_frames(frames, "idle", "Breathing_Idle", IDLE_FRAME_COUNT, 3.0)
	animated_sprite.sprite_frames = frames
	animated_sprite.play(&"idle_south")

func _add_directional_frames(frames: SpriteFrames, animation_prefix: String, folder: String, frame_count: int, speed: float) -> void:
	for direction in ["south", "south-east", "east", "north-east", "north"]:
		var animation_name := StringName("%s_%s" % [animation_prefix, direction.replace("-", "_")])
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, speed)
		frames.set_animation_loop(animation_name, true)
		for index in range(frame_count):
			var frame_path := "%s/%s/%s/frame_%03d.png" % [IVEN_ANIMATION_ROOT, folder, direction, index]
			var frame_texture := load(frame_path) as Texture2D
			if frame_texture != null:
				frames.add_frame(animation_name, frame_texture)

func _directional_animation_name(direction: Vector2, prefix: String) -> StringName:
	var normalized := direction.normalized()
	var horizontal_flip := normalized.x < -0.12
	animated_sprite.flip_h = horizontal_flip
	var suffix := "south"
	if normalized.y < -0.72:
		suffix = "north"
	elif normalized.y > 0.72:
		suffix = "south"
	elif absf(normalized.x) > 0.72:
		suffix = "east"
	elif normalized.y < 0.0:
		suffix = "north_east"
	else:
		suffix = "south_east"
	return StringName("%s_%s" % [prefix, suffix])

func _draw() -> void:
	# In @tool mode component children are placeholder Nodes, so querying combat
	# or abilities here prevents the ReturnJourney inspector preview from updating.
	if Engine.is_editor_hint():
		return
	if abilities.is_dashing():
		draw_circle(-abilities.get_dash_direction() * 13.0, BODY_RADIUS, Color(DASH_COLOR, 0.28))
	var has_sprite := animated_sprite.sprite_frames != null
	if not has_sprite:
		var body_color := Color("ffb3b3") if health.is_flashing() else BODY_COLOR
		draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
		var cloak_color := DIRTY_CLOAK_COLOR if visual_variant == &"dirty" else CLEAN_CLOAK_COLOR
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(0, 30)]), cloak_color)
		if visual_variant == &"dirty":
			draw_circle(Vector2(0, -5), 13.0, Color("34302d"))
			draw_line(Vector2(-12, 14), Vector2(13, 22), Color("8c7963"), 3.0)
		draw_circle(facing_direction * 6.0 + Vector2(0, -4), 3.0, Color("18212d"))
	if combat.is_attacking():
		var attack_angle := facing_direction.angle()
		var strength := combat.get_attack_progress()
		draw_arc(Vector2.ZERO, 54.0, attack_angle - 0.75, attack_angle + 0.75, 16, Color(ATTACK_COLOR, 0.95 - strength * 0.35), 5.0, true)
	if defense.is_parrying():
		draw_arc(Vector2.ZERO, 42.0, facing_direction.angle() - 0.95, facing_direction.angle() + 0.95, 18, Color("8fe8ef"), 4.0, true)
