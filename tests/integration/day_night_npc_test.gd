extends SceneTree

const SCHEDULE_PATHS := [
	"res://data/npcs/oren_schedule.json",
	"res://data/npcs/mira_schedule.json",
	"res://data/npcs/elian_schedule.json",
	"res://data/npcs/alda_schedule.json",
	"res://data/npcs/bram_schedule.json",
	"res://data/npcs/cerys_schedule.json",
]

var _avoidance_velocity_event_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cycle := root.get_node("/root/DayNightCycle")
	cycle.reset_clock()
	cycle.set_paused(true)
	_test_cycle(cycle)
	await _test_environment(cycle)
	await _test_scheduled_npc(cycle)
	await _test_parallel_npc_avoidance(cycle)
	_test_all_schedule_files()
	cycle.reset_clock()
	print("DAY_NIGHT_NPC_TEST: PASS")
	quit(0)


func _test_cycle(cycle: Node) -> void:
	cycle.set_time(6, 0)
	assert(cycle.get_phase() == &"dawn")
	assert(not cycle.should_world_lights_be_enabled())
	assert(cycle.get_formatted_time() == "06:00")

	cycle.set_time(18, 45)
	assert(cycle.get_phase() == &"dusk")
	assert(cycle.should_world_lights_be_enabled())
	var dusk_color: Color = cycle.get_ambient_color()

	cycle.set_time(12, 0)
	assert(cycle.get_phase() == &"day")
	assert(not cycle.should_world_lights_be_enabled())
	var day_color: Color = cycle.get_ambient_color()
	assert(
		not dusk_color.is_equal_approx(day_color),
		"Day and dusk must expose different ambient colors."
	)
	cycle.set_time(0, 0)
	var night_color: Color = cycle.get_ambient_color()
	assert(
		night_color.get_luminance() < day_color.get_luminance() * 0.5,
		"Night ambient must be substantially darker than daylight."
	)
	assert(
		night_color.b > night_color.r,
		"Night ambient must retain a blue-violet color cast."
	)

	cycle.set_time(8, 0, 2)
	cycle.set_day_duration_seconds(120.0)
	cycle.set_time_scale(2.0)
	cycle.set_paused(false)
	cycle.advance_real_seconds(10.0)
	cycle.set_paused(true)
	assert(
		is_equal_approx(cycle.get_hour_decimal(), 12.0),
		"A 120 second day at 2x must advance four hours in ten seconds."
	)
	assert(cycle.day_index == 2)

	var snapshot: Dictionary = cycle.create_snapshot()
	cycle.set_time(23, 0, 5)
	cycle.restore_snapshot(snapshot)
	assert(cycle.day_index == 2)
	assert(cycle.get_formatted_time() == "12:00")


func _test_environment(cycle: Node) -> void:
	cycle.set_time(21, 0)
	var world := Node2D.new()
	world.name = "EnvironmentTest"
	root.add_child(world)

	var ambient := CanvasModulate.new()
	ambient.name = "Ambient"
	world.add_child(ambient)
	var lights := Node2D.new()
	lights.name = "Lights"
	world.add_child(lights)
	for index in range(2):
		var light := PointLight2D.new()
		light.name = "Lamp%d" % index
		lights.add_child(light)

	var environment_script := load(
		"res://scripts/world/day_night_environment.gd"
	)
	var environment: Node = environment_script.new()
	environment.name = "DayNightEnvironment"
	environment.canvas_modulate_path = NodePath("../Ambient")
	environment.lights_root_path = NodePath("../Lights")
	environment.auto_discover_group = false
	environment.color_smoothing_speed = 0.0
	world.add_child(environment)
	await process_frame

	assert(environment.get_managed_light_count() == 2)
	for child in lights.get_children():
		var point_light := child as PointLight2D
		assert(
			point_light.enabled,
			"Street lights must be enabled at night."
		)
		assert(
			point_light.color.is_equal_approx(
				environment.warm_light_color
			),
			"Night lights must use the shared warm color profile."
		)
		assert(
			point_light.texture_scale >= 2.6,
			"Night lights must cast a broad, soft pool."
		)
		assert(
			point_light.energy > 0.0,
			"Night lights must receive profile energy."
		)
	assert(
		ambient.color.is_equal_approx(cycle.get_ambient_color()),
		"CanvasModulate must use the cycle ambient color."
	)

	cycle.set_time(10, 0)
	await process_frame
	environment.apply_now()
	for child in lights.get_children():
		assert(
			not (child as PointLight2D).enabled,
			"Street lights must be disabled during the day."
		)
	world.queue_free()
	await process_frame


func _test_scheduled_npc(cycle: Node) -> void:
	cycle.set_time(8, 30)
	var world := Node2D.new()
	world.name = "ScheduleTest"
	root.add_child(world)
	var locations := Node2D.new()
	locations.name = "Locations"
	world.add_child(locations)
	_add_marker(locations, "oren_home", Vector2(0.0, 0.0))
	_add_marker(locations, "gate_oren", Vector2(100.0, 20.0))
	_add_marker(locations, "town_well", Vector2(220.0, 80.0))
	_add_marker(locations, "tavern_porch", Vector2(320.0, 120.0))

	var npc_scene := load(
		"res://scenes/npcs/ScheduledNPC.tscn"
	) as PackedScene
	assert(npc_scene != null)
	var oren := npc_scene.instantiate()
	oren.npc_id = &"oren"
	oren.schedule_path = "res://data/npcs/oren_schedule.json"
	oren.location_root_path = NodePath("../Locations")
	world.add_child(oren)
	await process_frame

	assert(oren.get_schedule_entry_count() == 6)
	assert(oren.get_named_location_count() == 4)
	assert(oren.get_current_location_id() == &"gate_oren")
	assert(oren.get_current_activity() == &"guard_gate")
	assert(
		oren.global_position == Vector2(100.0, 20.0),
		"NPC must spawn at the correct location for the current hour."
	)

	cycle.set_time(12, 5)
	await process_frame
	assert(oren.get_target_location_id() == &"town_well")
	assert(oren.get_current_activity() == &"midday_break")
	assert(
		oren.is_travelling(),
		"A schedule boundary must start travel instead of teleporting."
	)
	oren.global_position = Vector2(220.0, 80.0)
	oren._physics_process(1.0 / 60.0)
	assert(not oren.is_travelling())
	assert(oren.get_current_location_id() == &"town_well")

	world.queue_free()
	await process_frame

	cycle.set_time(19, 30)
	var late_world := Node2D.new()
	late_world.name = "LateScheduleTest"
	root.add_child(late_world)
	var late_locations := Node2D.new()
	late_locations.name = "Locations"
	late_world.add_child(late_locations)
	_add_marker(late_locations, "oren_home", Vector2(0.0, 0.0))
	_add_marker(late_locations, "gate_oren", Vector2(100.0, 20.0))
	_add_marker(late_locations, "town_well", Vector2(220.0, 80.0))
	_add_marker(
		late_locations,
		"tavern_porch",
		Vector2(320.0, 120.0)
	)
	var late_oren := npc_scene.instantiate()
	late_oren.npc_id = &"oren"
	late_oren.schedule_path = "res://data/npcs/oren_schedule.json"
	late_oren.location_root_path = NodePath("../Locations")
	late_world.add_child(late_oren)
	await process_frame
	assert(
		late_oren.get_current_location_id() == &"tavern_porch",
		"NPC entering a scene mid-cycle must initialize from current time."
	)
	assert(late_oren.global_position == Vector2(320.0, 120.0))
	late_world.queue_free()
	await process_frame


func _test_parallel_npc_avoidance(cycle: Node) -> void:
	cycle.set_time(8, 30)
	var world := Node2D.new()
	world.name = "ParallelScheduleTest"
	root.add_child(world)
	var navigation_region := NavigationRegion2D.new()
	navigation_region.name = "NavigationRegion2D"
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.vertices = PackedVector2Array([
		Vector2(-180.0, -90.0),
		Vector2(180.0, -90.0),
		Vector2(180.0, 90.0),
		Vector2(-180.0, 90.0),
	])
	navigation_polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_region.navigation_polygon = navigation_polygon
	world.add_child(navigation_region)

	var locations := Node2D.new()
	locations.name = "Locations"
	world.add_child(locations)
	_add_marker(locations, "oren_home", Vector2(-140.0, -60.0))
	_add_marker(locations, "gate_oren", Vector2(-120.0, -24.0))
	_add_marker(locations, "town_well", Vector2(120.0, 24.0))
	_add_marker(locations, "tavern_porch", Vector2(140.0, 60.0))
	_add_marker(locations, "mira_home", Vector2(140.0, -60.0))
	_add_marker(locations, "gate_mira", Vector2(120.0, 24.0))
	_add_marker(locations, "bakery_door", Vector2(-120.0, -24.0))

	var npc_scene := load(
		"res://scenes/npcs/ScheduledNPC.tscn"
	) as PackedScene
	var oren := npc_scene.instantiate()
	oren.npc_id = &"oren"
	oren.schedule_path = "res://data/npcs/oren_schedule.json"
	oren.location_root_path = NodePath("../Locations")
	world.add_child(oren)
	var mira := npc_scene.instantiate()
	mira.npc_id = &"mira"
	mira.schedule_path = "res://data/npcs/mira_schedule.json"
	mira.location_root_path = NodePath("../Locations")
	world.add_child(mira)
	await physics_frame
	await physics_frame

	assert(oren.navigation_agent.avoidance_enabled)
	assert(mira.navigation_agent.avoidance_enabled)
	assert(oren.get_current_location_id() == &"gate_oren")
	assert(mira.get_current_location_id() == &"gate_mira")
	var oren_start: Vector2 = oren.global_position
	var mira_start: Vector2 = mira.global_position
	_avoidance_velocity_event_count = 0
	oren.navigation_agent.velocity_computed.connect(
		_on_test_velocity_computed
	)
	mira.navigation_agent.velocity_computed.connect(
		_on_test_velocity_computed
	)

	cycle.set_time(12, 5)
	assert(oren.is_travelling())
	assert(mira.is_travelling())
	for _frame_index in range(600):
		await physics_frame
		if not oren.is_travelling() and not mira.is_travelling():
			break

	assert(
		_avoidance_velocity_event_count > 0,
		"Avoidance must compute safe velocities for parallel NPC travel."
	)
	assert(
		oren.global_position.distance_to(oren_start) > 80.0,
		"Oren must make progress while another NPC crosses his route."
	)
	assert(
		mira.global_position.distance_to(mira_start) > 80.0,
		"Mira must make progress while another NPC crosses her route."
	)
	assert(
		not oren.is_travelling() and not mira.is_travelling(),
		"Both NPCs must complete their crossing routes without deadlock."
	)
	assert(oren.get_current_location_id() == &"town_well")
	assert(mira.get_current_location_id() == &"bakery_door")
	world.queue_free()
	await process_frame


func _on_test_velocity_computed(_safe_velocity: Vector2) -> void:
	_avoidance_velocity_event_count += 1


func _test_all_schedule_files() -> void:
	for path in SCHEDULE_PATHS:
		assert(FileAccess.file_exists(path), "Missing schedule: %s" % path)
		var file := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		assert(parsed is Dictionary, "Invalid schedule JSON: %s" % path)
		var data: Dictionary = parsed
		assert(not String(data.get("npc_id", "")).is_empty())
		var entries: Array = data.get("entries", [])
		assert(entries.size() >= 5, "Schedule is too sparse: %s" % path)


func _add_marker(
	parent: Node2D,
	marker_name: String,
	position: Vector2
) -> void:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = position
	parent.add_child(marker)
