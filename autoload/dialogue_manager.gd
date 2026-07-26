extends Node

signal memory_changed(npc_id: StringName, key: StringName, value: Variant)
signal choice_recorded(choice_id: StringName)

var npc_memory: Dictionary = {}


func remember(
	npc_id: StringName,
	key: StringName,
	value: Variant
) -> void:
	var memory: Dictionary = Dictionary(
		npc_memory.get(String(npc_id), {})
	).duplicate(true)
	memory[String(key)] = value
	npc_memory[String(npc_id)] = memory
	memory_changed.emit(npc_id, key, value)


func recall(
	npc_id: StringName,
	key: StringName,
	default_value: Variant = null
) -> Variant:
	var memory: Dictionary = npc_memory.get(String(npc_id), {})
	return memory.get(String(key), default_value)


func remembers(npc_id: StringName, key: StringName) -> bool:
	var memory: Dictionary = npc_memory.get(String(npc_id), {})
	return memory.has(String(key))


func record_choice(choice: Dictionary) -> void:
	var memory: Dictionary = choice.get("memory", {})
	if not memory.is_empty():
		remember(
			StringName(memory.get("npc", "global")),
			StringName(memory.get("key", "choice")),
			memory.get("value")
		)
	var world_flag := StringName(choice.get("world_flag", ""))
	if world_flag != &"":
		WorldState.set_flag(world_flag)
	choice_recorded.emit(StringName(choice.get("id", "")))


func create_snapshot() -> Dictionary:
	return npc_memory.duplicate(true)


func restore_snapshot(snapshot: Dictionary) -> void:
	npc_memory = snapshot.duplicate(true)


func reset_runtime_state() -> void:
	npc_memory.clear()
