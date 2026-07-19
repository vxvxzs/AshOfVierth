class_name EnemyBase
extends CharacterBody2D

signal defeated

enum State { CHASE, TELEGRAPH, RECOVERY }

@export_category("Combat Tuning")
@export var max_health := 2
@export var move_speed := 82.0
@export var attack_range := 82.0
@export var attack_reach := 40.0
@export var telegraph_duration := 0.55
@export var recovery_duration := 0.42
@export var active_hit_duration := 0.14

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_collision: CollisionShape2D = $AttackHitbox/CollisionShape2D

var health := 0
var flash_time_left := 0.0
var has_reported_defeat := false
var state := State.CHASE
var state_time_left := 0.0
var facing_direction := Vector2.DOWN
var has_hit_this_swing := false

func _ready() -> void:
	health = max_health
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
			if global_position.distance_to(player.global_position) <= attack_range:
				velocity = Vector2.ZERO
				state = State.TELEGRAPH
				state_time_left = telegraph_duration
			else:
				velocity = facing_direction * move_speed
				move_and_slide()
		State.TELEGRAPH:
			state_time_left -= delta
			if state_time_left <= 0.0:
				_start_attack()
		State.RECOVERY:
			state_time_left -= delta
			if state_time_left <= recovery_duration - active_hit_duration:
				_disable_attack_hitbox()
			if state_time_left <= 0.0:
				state = State.CHASE
	queue_redraw()

func take_damage(amount: int) -> void:
	if has_reported_defeat:
		return
	health -= amount
	flash_time_left = 0.10
	if health <= 0:
		has_reported_defeat = true
		_disable_attack_hitbox()
		_on_defeated()
		defeated.emit()
		queue_free()

func is_telegraphing() -> bool:
	return state == State.TELEGRAPH

func _on_defeated() -> void:
	pass

func _start_attack() -> void:
	state = State.RECOVERY
	state_time_left = recovery_duration
	has_hit_this_swing = false
	attack_hitbox.position = facing_direction * attack_reach
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
