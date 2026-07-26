extends Node

signal world_state_saved
signal world_state_load_failed

const WORLD_STATE_SAVE_PATH := "user://world_state.save.json"

func save_world_state() -> bool:
	var file := FileAccess.open(WORLD_STATE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var snapshot := WorldState.create_snapshot()
	var memory_manager := get_node_or_null("/root/DialogueManager")
	if memory_manager != null:
		snapshot["npc_memory"] = memory_manager.create_snapshot()
	var day_night_cycle := get_node_or_null("/root/DayNightCycle")
	if day_night_cycle != null:
		snapshot["world_time"] = day_night_cycle.create_snapshot()
	file.store_string(JSON.stringify(snapshot))
	world_state_saved.emit()
	return true

func load_world_state() -> bool:
	if not FileAccess.file_exists(WORLD_STATE_SAVE_PATH):
		return false
	var file := FileAccess.open(WORLD_STATE_SAVE_PATH, FileAccess.READ)
	if file == null:
		world_state_load_failed.emit()
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		world_state_load_failed.emit()
		return false
	WorldState.restore_snapshot(parsed)
	var memory_manager := get_node_or_null("/root/DialogueManager")
	if memory_manager != null:
		memory_manager.restore_snapshot(
			Dictionary(parsed.get("npc_memory", {}))
		)
	var day_night_cycle := get_node_or_null("/root/DayNightCycle")
	if day_night_cycle != null and parsed.has("world_time"):
		day_night_cycle.restore_snapshot(
			Dictionary(parsed.get("world_time", {}))
		)
	return true

func has_world_state_save() -> bool:
	return FileAccess.file_exists(WORLD_STATE_SAVE_PATH)
