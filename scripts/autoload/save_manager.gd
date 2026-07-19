extends Node

signal world_state_saved
signal world_state_load_failed

const WORLD_STATE_SAVE_PATH := "user://world_state.save.json"

func save_world_state() -> bool:
	var file := FileAccess.open(WORLD_STATE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(WorldState.create_snapshot()))
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
	return true

func has_world_state_save() -> bool:
	return FileAccess.file_exists(WORLD_STATE_SAVE_PATH)
