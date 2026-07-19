class_name Player
extends CharacterBody2D

const BODY_RADIUS := 18.0
const BODY_COLOR := Color("d8e7ff")
const CLOAK_COLOR := Color("3f668a")
const DASH_COLOR := Color("87d7ff")
const ATTACK_COLOR := Color("f4cf8c")

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var abilities: PlayerAbilities = $Abilities
@onready var health = $Health

var facing_direction := Vector2.DOWN
var mobile_move_input := Vector2.ZERO

signal died

func _ready() -> void:
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	health.died.connect(_on_health_depleted)
	if ProgressionManager.is_ability_unlocked(&"short_step"):
		abilities.unlock_short_step()

func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	var input_direction := Vector2.ZERO if _is_dialogue_open() else _read_movement_input()
	if input_direction != Vector2.ZERO:
		facing_direction = input_direction

	abilities.tick(delta)
	health.tick(delta)
	combat.tick(delta)
	combat.update_hitbox_position(facing_direction)

	if abilities.is_dashing():
		velocity = abilities.get_dash_velocity()
	else:
		movement.update_velocity(self, input_direction, combat.get_move_speed_multiplier(), delta)

	move_and_slide()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _is_dialogue_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			request_short_step()
		elif event.keycode == KEY_J or event.keycode == KEY_Z:
			request_light_attack()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_light_attack()

func set_mobile_move_input(new_direction: Vector2) -> void:
	mobile_move_input = new_direction.limit_length(1.0)

func request_light_attack() -> void:
	if not _is_dialogue_open() and not health.is_dead():
		combat.try_light_attack()

func request_short_step() -> void:
	if not _is_dialogue_open() and not health.is_dead():
		abilities.try_dash(_read_movement_input(), facing_direction)

func _read_movement_input() -> Vector2:
	if mobile_move_input != Vector2.ZERO:
		return mobile_move_input
	return _read_keyboard_direction()

func _read_keyboard_direction() -> Vector2:
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

func unlock_short_step() -> void:
	abilities.unlock_short_step()

func _on_ability_unlocked(ability_id: StringName) -> void:
	if ability_id == &"short_step":
		unlock_short_step()

func take_damage(amount: int) -> void:
	if is_invulnerable():
		return
	health.take_damage(amount)
	queue_redraw()

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

func _draw() -> void:
	if abilities.is_dashing():
		draw_circle(-abilities.get_dash_direction() * 13.0, BODY_RADIUS, Color(DASH_COLOR, 0.28))
	var body_color := Color("ffb3b3") if health.is_flashing() else BODY_COLOR
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(0, 30)]), CLOAK_COLOR)
	draw_circle(facing_direction * 6.0 + Vector2(0, -4), 3.0, Color("18212d"))
	if combat.is_attacking():
		var attack_angle := facing_direction.angle()
		var strength := combat.get_attack_progress()
		draw_arc(Vector2.ZERO, 54.0, attack_angle - 0.75, attack_angle + 0.75, 16, Color(ATTACK_COLOR, 0.95 - strength * 0.35), 5.0, true)
