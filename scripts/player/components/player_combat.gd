class_name PlayerCombat
extends Node

signal stamina_changed(current_stamina: float, max_stamina: float)

const LIGHT_ATTACK_DURATION := 0.36
const LIGHT_ATTACK_ACTIVE_START := 0.10
const LIGHT_ATTACK_ACTIVE_END := 0.19
const ATTACK_COOLDOWN := 0.34
const LIGHT_ATTACK_STAMINA_COST := 24.0
const MAX_STAMINA := 100.0
const STAMINA_REGEN_PER_SECOND := 32.0
const STAMINA_REGEN_DELAY := 0.42
const ATTACK_REACH := 42.0
const ATTACK_MOVE_SPEED_MULTIPLIER := 0.50

@onready var attack_hitbox: Area2D = get_parent().get_node("AttackHitbox")
@onready var attack_collision: CollisionShape2D = attack_hitbox.get_node("CollisionShape2D")

var attack_time_left := 0.0
var attack_elapsed := 0.0
var attack_cooldown_left := 0.0
var stamina := MAX_STAMINA
var stamina_regen_delay_left := 0.0
var hit_target_ids: Dictionary = {}

func _ready() -> void:
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	stamina_changed.emit(stamina, MAX_STAMINA)

func try_light_attack() -> bool:
	if attack_time_left > 0.0 or attack_cooldown_left > 0.0 or stamina < LIGHT_ATTACK_STAMINA_COST:
		return false
	stamina -= LIGHT_ATTACK_STAMINA_COST
	stamina_regen_delay_left = STAMINA_REGEN_DELAY
	attack_cooldown_left = ATTACK_COOLDOWN
	attack_time_left = LIGHT_ATTACK_DURATION
	attack_elapsed = 0.0
	hit_target_ids.clear()
	stamina_changed.emit(stamina, MAX_STAMINA)
	return true

func tick(delta: float) -> void:
	attack_cooldown_left = maxf(0.0, attack_cooldown_left - delta)
	if stamina_regen_delay_left > 0.0:
		stamina_regen_delay_left = maxf(0.0, stamina_regen_delay_left - delta)
	elif stamina < MAX_STAMINA:
		var previous_stamina := stamina
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN_PER_SECOND * delta)
		if floori(previous_stamina) != floori(stamina) or stamina == MAX_STAMINA:
			stamina_changed.emit(stamina, MAX_STAMINA)
	if attack_time_left <= 0.0:
		return
	attack_time_left = maxf(0.0, attack_time_left - delta)
	attack_elapsed += delta
	var hitbox_active := attack_elapsed >= LIGHT_ATTACK_ACTIVE_START and attack_elapsed <= LIGHT_ATTACK_ACTIVE_END
	attack_hitbox.monitoring = hitbox_active
	attack_collision.set_deferred("disabled", not hitbox_active)
	if attack_time_left <= 0.0:
		attack_hitbox.monitoring = false
		attack_collision.set_deferred("disabled", true)

func update_hitbox_position(facing_direction: Vector2) -> void:
	attack_hitbox.position = facing_direction * ATTACK_REACH

func is_attacking() -> bool:
	return attack_time_left > 0.0

func get_move_speed_multiplier() -> float:
	return ATTACK_MOVE_SPEED_MULTIPLIER if is_attacking() else 1.0

func get_attack_progress() -> float:
	return 1.0 - attack_time_left / LIGHT_ATTACK_DURATION

func get_stamina() -> float:
	return stamina

func _on_attack_area_entered(area: Area2D) -> void:
	if not is_attacking():
		return
	var target := area.get_parent()
	if not target.has_method("take_damage"):
		return
	var target_id := target.get_instance_id()
	if hit_target_ids.has(target_id):
		return
	hit_target_ids[target_id] = true
	target.take_damage(1)
