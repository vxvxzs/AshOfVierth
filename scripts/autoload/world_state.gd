extends Node

signal death_count_changed(new_value: int)
signal flag_changed(flag_id: StringName, value: Variant)
signal anchor_changed(anchor_id: StringName, spawn_position: Vector2)

var death_count := 0
var flags: Dictionary = {}
var current_anchor_id: StringName = &""
var current_anchor_position := Vector2.ZERO

func register_death() -> void:
	death_count += 1
	death_count_changed.emit(death_count)

func get_memory_state() -> String:
	if death_count == 0:
		return "Stable"
	if death_count < 4:
		return "Thin"
	return "Fractured"

func set_flag(flag_id: StringName, value: Variant = true) -> void:
	flags[flag_id] = value
	flag_changed.emit(flag_id, value)

func has_flag(flag_id: StringName) -> bool:
	return bool(flags.get(flag_id, false))

func get_flag(flag_id: StringName, default_value: Variant = false) -> Variant:
	return flags.get(flag_id, default_value)

func set_anchor(anchor_id: StringName, spawn_position: Vector2) -> void:
	current_anchor_id = anchor_id
	current_anchor_position = spawn_position
	anchor_changed.emit(current_anchor_id, current_anchor_position)

func has_anchor() -> bool:
	return current_anchor_id != &""

func create_snapshot() -> Dictionary:
	return {
		"death_count": death_count,
		"flags": flags.duplicate(true),
		"anchor_id": String(current_anchor_id),
		"anchor_position": { "x": current_anchor_position.x, "y": current_anchor_position.y }
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	death_count = int(snapshot.get("death_count", 0))
	flags = Dictionary(snapshot.get("flags", {})).duplicate(true)
	current_anchor_id = StringName(snapshot.get("anchor_id", ""))
	var anchor_data: Dictionary = snapshot.get("anchor_position", {})
	current_anchor_position = Vector2(float(anchor_data.get("x", 0.0)), float(anchor_data.get("y", 0.0)))

func reset_runtime_state() -> void:
	death_count = 0
	flags.clear()
	current_anchor_id = &""
	current_anchor_position = Vector2.ZERO
