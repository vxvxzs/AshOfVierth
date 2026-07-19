extends SceneTree

func _init() -> void:
	_test_world_state_snapshot()
	_test_dialogue_conditions()
	_test_enemy_framework()
	print("SYSTEM_SMOKE_TEST: PASS")
	quit(0)

func _test_world_state_snapshot() -> void:
	var world_state_script = load("res://scripts/autoload/world_state.gd")
	var state = world_state_script.new()
	state.set_anchor(&"test_anchor", Vector2(128.0, 256.0))
	state.set_flag(&"region1_boss_seen")
	state.register_death()
	state.register_death()
	assert(state.death_count == 2)
	assert(state.get_memory_state() == "Thin")
	assert(state.has_flag(&"region1_boss_seen"))
	var snapshot: Dictionary = state.create_snapshot()
	var restored_state = world_state_script.new()
	restored_state.restore_snapshot(snapshot)
	assert(restored_state.death_count == 2)
	assert(restored_state.current_anchor_id == &"test_anchor")
	assert(restored_state.current_anchor_position == Vector2(128.0, 256.0))
	state.free()
	restored_state.free()

func _test_dialogue_conditions() -> void:
	var world_state_script = load("res://scripts/autoload/world_state.gd")
	var state = world_state_script.new()
	var resolver_script = load("res://scripts/dialogue/dialogue_resolver.gd")
	var first_lines: Array = resolver_script.get_lines("spirit", state)
	assert(first_lines.size() == 3)
	assert(first_lines[0].get("text") == "Wait. Do not move the shard.")
	state.set_flag(&"spirit_met")
	state.register_death()
	var remembered_lines: Array = resolver_script.get_lines("spirit", state)
	assert(remembered_lines[0].get("text") == "I remembered you falling before I saw you wake.")
	state.free()

func _test_enemy_framework() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/BrittleEcho.tscn")
	var enemy = enemy_scene.instantiate()
	root.add_child(enemy)
	assert(enemy.has_method("take_damage"))
	assert(enemy.has_method("is_telegraphing"))
	enemy.free()
