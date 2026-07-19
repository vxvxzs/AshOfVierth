class_name BrittleEcho
extends CharacterBody2D

signal defeated

enum State { CHASE, TELEGRAPH, RECOVERY }

const MAX_HEALTH := 2
const BODY_RADIUS := 19.0
const BODY_COLOR := Color("9875bd")
const HURT_COLOR := Color("f1c9ff")
const TELEGRAPH_COLOR := Color("ff8f8f")
const MOVE_SPEED := 82.0
const ATTACK_RANGE := 82.0
const TELEGRAPH_DURATION := 0.55
const RECOVERY_DURATION := 0.42
const ACTIVE_HIT_DURATION := 0.14

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_collision: CollisionShape2D = $AttackHitbox/CollisionShape2D

var health := MAX_HEALTH
var flash_time_left := 0.0
var has_reported_defeat := false
var state := State.CHASE
var state_time_left := 0.0
var facing_direction := Vector2.DOWN
var has_hit_this_swing := false

func _ready() -> void:
	attack_hitbox.area_entered.connect(_on_attack_area_entered)

func _physics_process(delta: float) -> void:
	flash_time_left = maxf(0.0, flash_time_left - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var direction_to_player := global_position.direction_to(player.global_position)
	if direction_to_player != Vector2.ZERO:
		facing_direction = direction_to_player

	match state:
		State.CHASE:
			var distance_to_player := global_position.distance_to(player.global_position)
			if distance_to_player <= ATTACK_RANGE:
				velocity = Vector2.ZERO
				state = State.TELEGRAPH
				state_time_left = TELEGRAPH_DURATION
			else:
				velocity = facing_direction * MOVE_SPEED
				move_and_slide()
		State.TELEGRAPH:
			state_time_left -= delta
			if state_time_left <= 0.0:
				_start_attack()
		State.RECOVERY:
			state_time_left -= delta
			if state_time_left <= RECOVERY_DURATION - ACTIVE_HIT_DURATION:
				_disable_attack_hitbox()
			if state_time_left <= 0.0:
				state = State.CHASE
	queue_redraw()

func _start_attack() -> void:
	state = State.RECOVERY
	state_time_left = RECOVERY_DURATION
	has_hit_this_swing = false
	attack_hitbox.position = facing_direction * 40.0
	attack_hitbox.monitoring = true
	attack_collision.set_deferred("disabled", false)

func _disable_attack_hitbox() -> void:
	attack_hitbox.monitoring = false
	attack_collision.set_deferred("disabled", true)

func _on_attack_area_entered(area: Area2D) -> void:
	if has_hit_this_swing:
		return
	var target := area.get_parent()
	if target.has_method("take_damage"):
		has_hit_this_swing = true
		target.take_damage(1)

func take_damage(amount: int) -> void:
	if has_reported_defeat:
		return
	health -= amount
	flash_time_left = 0.10
	if health <= 0:
		has_reported_defeat = true
		_disable_attack_hitbox()
		ProgressionManager.register_echo_defeated()
		defeated.emit()
		queue_free()

func _draw() -> void:
	var color := HURT_COLOR if flash_time_left > 0.0 else BODY_COLOR
	if state == State.TELEGRAPH:
		color = TELEGRAPH_COLOR
	draw_circle(Vector2.ZERO, BODY_RADIUS, color)
	draw_arc(Vector2.ZERO, BODY_RADIUS + 6.0, -2.2, 0.7, 12, Color("d8b7ef", 0.75), 2.0, true)
	draw_circle(Vector2(-6, -3), 2.0, Color("1d1527"))
	draw_circle(Vector2(6, -3), 2.0, Color("1d1527"))
	if state == State.TELEGRAPH:
		draw_arc(Vector2.ZERO, 48.0, facing_direction.angle() - 0.6, facing_direction.angle() + 0.6, 12, Color(TELEGRAPH_COLOR, 0.9), 3.0, true)
