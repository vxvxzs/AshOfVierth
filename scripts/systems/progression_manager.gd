extends Node

signal light_points_changed(new_value: int)
signal echo_kills_changed(new_value: int)
signal reward_granted(amount: int)
signal ability_unlocked(ability_id: StringName)
signal objective_changed(new_objective: String)

const ECHO_KILLS_FOR_FIRST_REWARD := 5
const FIRST_REWARD_LIGHT := 3
const SHORT_STEP_COST := 3

var light_points := 0
var echo_kills := 0
var first_reward_claimed := false
var unlocked_abilities: Dictionary = {}
var current_objective := ""

func register_echo_defeated() -> void:
	echo_kills += 1
	echo_kills_changed.emit(echo_kills)
	if echo_kills >= ECHO_KILLS_FOR_FIRST_REWARD and not first_reward_claimed:
		first_reward_claimed = true
		add_light(FIRST_REWARD_LIGHT)
		reward_granted.emit(FIRST_REWARD_LIGHT)

func add_light(amount: int) -> void:
	light_points += amount
	light_points_changed.emit(light_points)

func unlock_short_step() -> bool:
	if is_ability_unlocked(&"short_step") or light_points < SHORT_STEP_COST:
		return false
	light_points -= SHORT_STEP_COST
	unlocked_abilities[&"short_step"] = true
	light_points_changed.emit(light_points)
	ability_unlocked.emit(&"short_step")
	return true

func is_ability_unlocked(ability_id: StringName) -> bool:
	return unlocked_abilities.has(ability_id)

func set_objective(new_objective: String) -> void:
	current_objective = new_objective
	objective_changed.emit(current_objective)
