class_name ScheduledNPC
extends CharacterBody2D

signal schedule_loaded(npc_id: StringName)
signal routine_changed(
	npc_id: StringName,
	location_id: StringName,
	activity: StringName
)
signal destination_reached(
	npc_id: StringName,
	location_id: StringName
)

@export var npc_id: StringName = &"villager"
@export var display_name := "Villager"
@export_file("*.json") var schedule_path := ""
@export var location_root_path: NodePath
@export_range(4.0, 240.0, 1.0) var walk_speed := 38.0
@export_range(1.0, 32.0, 0.5) var arrival_distance := 5.0
@export var snap_to_schedule_on_ready := true
@export_category("Navigation Avoidance")
@export var avoidance_enabled := true
@export_range(1.0, 64.0, 0.5) var avoidance_radius := 9.0
@export_range(8.0, 256.0, 1.0) var avoidance_neighbor_distance := 72.0
@export_range(1, 32, 1) var avoidance_max_neighbors := 8
@export_range(0.1, 5.0, 0.1) var avoidance_agent_horizon := 1.2
@export_range(0.1, 5.0, 0.1) var avoidance_obstacle_horizon := 0.8

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var name_label: Label = $Name

var _cycle: Node
var _schedule_entries: Array[Dictionary] = []
var _named_locations: Dictionary = {}
var _active_entry_index := -1
var _current_location_id: StringName = &""
var _target_location_id: StringName = &""
var _current_activity: StringName = &"idle"
var _target_position := Vector2.ZERO
var _has_destination := false
var _initialized := false
var _requested_velocity := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"scheduled_npc")
	name_label.text = display_name
	navigation_agent.path_desired_distance = arrival_distance
	navigation_agent.target_desired_distance = arrival_distance
	navigation_agent.avoidance_enabled = avoidance_enabled
	navigation_agent.radius = avoidance_radius
	navigation_agent.neighbor_distance = avoidance_neighbor_distance
	navigation_agent.max_neighbors = avoidance_max_neighbors
	navigation_agent.time_horizon_agents = avoidance_agent_horizon
	navigation_agent.time_horizon_obstacles = avoidance_obstacle_horizon
	navigation_agent.max_speed = walk_speed
	navigation_agent.velocity_computed.connect(
		_on_avoidance_velocity_computed
	)
	_cycle = get_node_or_null("/root/DayNightCycle")
	if _cycle == null:
		push_warning("%s requires DayNightCycle autoload." % display_name)
	else:
		_cycle.time_changed.connect(_on_world_time_changed)
	if not schedule_path.is_empty():
		load_schedule(schedule_path)
	if not location_root_path.is_empty():
		var location_root := get_node_or_null(location_root_path)
		if location_root != null:
			configure_location_root(location_root, false)
	_initialize_from_current_time(snap_to_schedule_on_ready)


func _physics_process(_delta: float) -> void:
	if not _has_destination:
		velocity = Vector2.ZERO
		_requested_velocity = Vector2.ZERO
		return
	if global_position.distance_to(_target_position) <= arrival_distance:
		global_position = _target_position
		_finish_travel()
		return
	var next_position := _target_position
	var navigation_ready := _navigation_is_ready()
	if navigation_ready and not navigation_agent.is_navigation_finished():
		next_position = navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	_requested_velocity = direction * walk_speed
	if _requested_velocity.is_zero_approx():
		velocity = Vector2.ZERO
		return
	if avoidance_enabled and navigation_ready:
		navigation_agent.velocity = _requested_velocity
	else:
		_apply_velocity(_requested_velocity)


func _on_avoidance_velocity_computed(safe_velocity: Vector2) -> void:
	if not _has_destination:
		velocity = Vector2.ZERO
		return
	_apply_velocity(safe_velocity)


func _apply_velocity(next_velocity: Vector2) -> void:
	velocity = next_velocity.limit_length(walk_speed)
	move_and_slide()
	if global_position.distance_to(_target_position) <= arrival_distance:
		global_position = _target_position
		_finish_travel()


func load_schedule(path: String = schedule_path) -> bool:
	if path.is_empty():
		push_warning("%s has no schedule path." % display_name)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open NPC schedule: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("NPC schedule is not a JSON object: %s" % path)
		return false
	var schedule_data: Dictionary = parsed
	var file_npc_id := StringName(schedule_data.get("npc_id", npc_id))
	if npc_id == &"villager" or npc_id == &"":
		npc_id = file_npc_id
	display_name = String(schedule_data.get("display_name", display_name))
	walk_speed = float(schedule_data.get("walk_speed", walk_speed))
	if is_node_ready():
		name_label.text = display_name
		navigation_agent.max_speed = walk_speed
	_schedule_entries.clear()
	var raw_entries: Array = schedule_data.get("entries", [])
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		entry["minute"] = _parse_time_to_minute(
			String(entry.get("time", "00:00"))
		)
		entry["location"] = StringName(entry.get("location", ""))
		entry["activity"] = StringName(entry.get("activity", "idle"))
		_schedule_entries.append(entry)
	_schedule_entries.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return float(first["minute"]) < float(second["minute"])
	)
	schedule_path = path
	schedule_loaded.emit(npc_id)
	if is_node_ready():
		_initialize_from_current_time(
			snap_to_schedule_on_ready and not _initialized
		)
	return not _schedule_entries.is_empty()


func configure_locations(
	named_locations: Dictionary,
	snap_immediately: bool = true
) -> void:
	_named_locations.clear()
	for raw_id in named_locations:
		var location_value: Variant = named_locations[raw_id]
		if location_value is Vector2:
			_named_locations[StringName(raw_id)] = location_value
		elif location_value is Node2D:
			_named_locations[StringName(raw_id)] = (
				location_value as Node2D
			).global_position
	_initialize_from_current_time(snap_immediately)


func configure_location_root(
	location_root: Node,
	snap_immediately: bool = true
) -> void:
	_named_locations.clear()
	_collect_location_markers(location_root)
	_initialize_from_current_time(snap_immediately)


func refresh_schedule(snap_immediately: bool = false) -> void:
	_initialize_from_current_time(snap_immediately)


func get_current_location_id() -> StringName:
	return _current_location_id


func get_target_location_id() -> StringName:
	return _target_location_id


func get_current_activity() -> StringName:
	return _current_activity


func get_schedule_entry_count() -> int:
	return _schedule_entries.size()


func is_travelling() -> bool:
	return _has_destination


func get_named_location_count() -> int:
	return _named_locations.size()


func _initialize_from_current_time(snap_immediately: bool) -> void:
	if (
		_cycle == null
		or _schedule_entries.is_empty()
		or _named_locations.is_empty()
	):
		return
	var next_index := _find_active_entry_index(
		float(_cycle.minute_of_day)
	)
	if next_index < 0:
		return
	var entry_changed := next_index != _active_entry_index
	_active_entry_index = next_index
	var entry := _schedule_entries[_active_entry_index]
	var location_id := StringName(entry["location"])
	_current_activity = StringName(entry["activity"])
	if not _named_locations.has(location_id):
		push_warning(
			"%s schedule location '%s' is not configured."
			% [display_name, location_id]
		)
		return
	if snap_immediately or not _initialized:
		global_position = _named_locations[location_id]
		_current_location_id = location_id
		_target_location_id = &""
		_has_destination = false
		velocity = Vector2.ZERO
		_requested_velocity = Vector2.ZERO
		navigation_agent.velocity = Vector2.ZERO
		navigation_agent.target_position = global_position
	elif entry_changed and location_id != _current_location_id:
		_begin_travel(location_id)
	_initialized = true
	if entry_changed or snap_immediately:
		routine_changed.emit(
			npc_id,
			location_id,
			_current_activity
		)


func _on_world_time_changed(
	_day_index: int,
	current_minute: float
) -> void:
	if _schedule_entries.is_empty() or _named_locations.is_empty():
		return
	var next_index := _find_active_entry_index(current_minute)
	if next_index < 0 or next_index == _active_entry_index:
		return
	_active_entry_index = next_index
	var entry := _schedule_entries[_active_entry_index]
	var location_id := StringName(entry["location"])
	_current_activity = StringName(entry["activity"])
	if not _named_locations.has(location_id):
		push_warning(
			"%s schedule location '%s' is not configured."
			% [display_name, location_id]
		)
		return
	if location_id != _current_location_id:
		_begin_travel(location_id)
	routine_changed.emit(
		npc_id,
		location_id,
		_current_activity
	)


func _begin_travel(location_id: StringName) -> void:
	_target_location_id = location_id
	_target_position = _named_locations[location_id]
	_has_destination = true
	_requested_velocity = Vector2.ZERO
	navigation_agent.target_position = _target_position


func _finish_travel() -> void:
	velocity = Vector2.ZERO
	_requested_velocity = Vector2.ZERO
	navigation_agent.velocity = Vector2.ZERO
	_has_destination = false
	_current_location_id = _target_location_id
	_target_location_id = &""
	destination_reached.emit(npc_id, _current_location_id)


func _find_active_entry_index(current_minute: float) -> int:
	if _schedule_entries.is_empty():
		return -1
	var active_index := _schedule_entries.size() - 1
	for index in range(_schedule_entries.size()):
		if float(_schedule_entries[index]["minute"]) <= current_minute:
			active_index = index
		else:
			break
	return active_index


func _parse_time_to_minute(time_text: String) -> float:
	var parts := time_text.split(":")
	if parts.size() != 2:
		return 0.0
	var hour := clampi(int(parts[0]), 0, 23)
	var minute := clampi(int(parts[1]), 0, 59)
	return float(hour * 60 + minute)


func _collect_location_markers(node: Node) -> void:
	var marker := node as Marker2D
	if marker != null:
		var location_id := StringName(
			marker.get_meta(
				&"schedule_id",
				String(marker.name).to_snake_case()
			)
		)
		_named_locations[location_id] = marker.global_position
	for child in node.get_children():
		_collect_location_markers(child)


func _navigation_is_ready() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	return (
		navigation_map.is_valid()
		and NavigationServer2D.map_get_iteration_id(
			navigation_map
		) > 0
	)
