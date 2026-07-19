class_name DialogueResolver
extends RefCounted

const DIALOGUE_PATHS := {
	"spirit": "res://data/dialogue/spirit.json"
}

static func get_lines(dialogue_id: String, state: Node = null) -> Array:
	var active_state: Node = state if state != null else _get_runtime_world_state()
	if active_state == null:
		push_warning("Dialogue requested without a WorldState: %s" % dialogue_id)
		return []
	var definition := _load_definition(dialogue_id)
	for entry in definition.get("entries", []):
		if _matches_conditions(Dictionary(entry.get("conditions", {})), active_state):
			return Array(entry.get("lines", [])).duplicate(true)
	return []

static func _get_runtime_world_state() -> Node:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	return scene_tree.root.get_node_or_null("WorldState")

static func _load_definition(dialogue_id: String) -> Dictionary:
	var path: String = DIALOGUE_PATHS.get(dialogue_id, "")
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("Dialogue definition not found: %s" % dialogue_id)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_warning("Invalid dialogue JSON: %s" % dialogue_id)
	return {}

static func _matches_conditions(conditions: Dictionary, state: Node) -> bool:
	if conditions.is_empty():
		return true
	if state.death_count < int(conditions.get("min_deaths", 0)):
		return false
	if state.death_count > int(conditions.get("max_deaths", 999999)):
		return false
	for flag_id in Array(conditions.get("flags_all", [])):
		if not state.has_flag(StringName(flag_id)):
			return false
	for flag_id in Array(conditions.get("flags_none", [])):
		if state.has_flag(StringName(flag_id)):
			return false
	return true
