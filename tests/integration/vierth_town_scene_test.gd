extends SceneTree

const LEVEL_PATH := "res://scenes/levels/VierthTown.tscn"
const EXPECTED_LOCATIONS := [
	"gate",
	"market",
	"well",
	"bakery",
	"tavern",
	"oren_home",
	"mira_home",
	"elian_home",
	"resident_home_a",
	"resident_home_b",
	"resident_home_c",
	"gate_oren",
	"gate_mira",
	"town_well",
	"tavern_porch",
	"bakery_door",
	"bakery_oven",
	"bakery_counter",
	"market_bakery_stall",
	"alda_home",
	"river_bank",
	"market_cloth_stall",
	"bram_home",
	"bridge_south",
	"market_tool_stall",
	"tavern_interior",
	"cerys_home",
	"iven_house_gate",
	"town_square",
	"bridge_north",
]
const EXPECTED_0800_NPC_LOCATIONS := {
	&"oren": &"gate_oren",
	&"mira": &"gate_mira",
	&"elian": &"bakery_counter",
	&"alda": &"river_bank",
	&"bram": &"bridge_south",
	&"cerys": &"iven_house_gate",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(LEVEL_PATH) as PackedScene
	assert(packed != null, "VierthTown scene must load.")
	var town := packed.instantiate() as VierthTown
	assert(town != null, "VierthTown must use the modular level script.")
	root.add_child(town)
	await process_frame
	await physics_frame

	var ground := town.get_node("GroundLayer/ContinuousGround") as Sprite2D
	assert(ground != null and ground.texture != null, "Native ground texture must exist.")
	assert(
		ground.texture.get_size() == Vector2(1600, 1120),
		"Town ground must be generated at native 1:1 world-pixel density."
	)
	assert(
		ground.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"Town terrain must use nearest-neighbour filtering."
	)

	var world := town.get_node("World") as Node2D
	assert(world != null and world.y_sort_enabled, "Town props must share a y-sorted world.")
	var town_square := town.get_node("World/TownSquare") as Node2D
	assert(
		town_square != null and town_square.y_sort_enabled,
		"Nested market props must y-sort independently relative to Iven."
	)
	assert(town.has_node("World/TownSquare/Well"), "Town square must contain a well.")
	for stall_index in range(4):
		assert(
			town.has_node("World/TownSquare/MarketStall%02d" % stall_index),
			"Town square must contain all four market stalls."
		)
	assert(town.has_node("World/ElianBakery/BakerySign"), "Bakery sign is required.")
	assert(
		town.get_node("World/ElianBakery/ChimneySmoke") is GPUParticles2D,
		"Elian's bakery must have animated chimney smoke."
	)
	assert(town.has_node("World/Tavern/Porch"), "Tavern porch marker is required.")
	assert(town.has_node("World/IvenHouse"), "Iven's house is required.")
	assert(town.has_node("World/River"), "River landmark is required.")
	assert(town.has_node("World/StoneBridge"), "Stone bridge landmark is required.")
	var bridge := town.get_node("World/StoneBridge") as StaticBody2D
	assert(
		bridge != null
		and bridge.is_in_group(&"bridge_deck")
		and bridge.z_index < 0,
		"The bridge deck must render over water but below Iven."
	)
	var north_blocker := town.get_node(
		"World/River/RiverBlockNorth"
	) as StaticBody2D
	var south_blocker := town.get_node(
		"World/River/RiverBlockSouth"
	) as StaticBody2D
	assert(
		north_blocker != null and south_blocker != null,
		"River banks must have physical blockers outside the stone bridge."
	)
	for blocker: StaticBody2D in [north_blocker, south_blocker]:
		var blocker_collision := blocker.get_node(
			"CollisionShape2D"
		) as CollisionShape2D
		assert(
			blocker_collision != null
			and blocker_collision.shape is RectangleShape2D,
			"Every river blocker must expose a rectangular physics shape."
		)
	var physics_space := town.get_world_2d().direct_space_state
	var blocked_crossing_query := PhysicsRayQueryParameters2D.create(
		Vector2(1129.5, 256.0),
		Vector2(1366.5, 256.0),
		1
	)
	var bridge_crossing_query := PhysicsRayQueryParameters2D.create(
		Vector2(1129.5, 544.0),
		Vector2(1366.5, 544.0),
		1
	)
	assert(
		not physics_space.intersect_ray(blocked_crossing_query).is_empty(),
		"River collision must block crossing away from the bridge."
	)
	assert(
		physics_space.intersect_ray(bridge_crossing_query).is_empty(),
		"The stone bridge corridor must remain physically passable."
	)
	var base_collider_paths := [
		"World/TownSquare/MarketStall00",
		"World/TownSquare/MarketStall01",
		"World/TownSquare/MarketStall02",
		"World/TownSquare/MarketStall03",
		"World/ElianBakery",
		"World/Tavern",
		"World/IvenHouse",
		"World/ResidentHouseA",
		"World/ResidentHouseB",
		"World/ResidentHouseC",
		"World/StreetLamp00",
		"World/StreetLamp01",
	]
	for collider_path: String in base_collider_paths:
		var prop := town.get_node(collider_path) as StaticBody2D
		var sprite := prop.get_node("Sprite") as Sprite2D
		var collision := prop.get_node("CollisionShape2D") as CollisionShape2D
		var base_shape := collision.shape as RectangleShape2D
		assert(
			prop.is_in_group(&"ground_base_collider")
			and sprite != null
			and sprite.texture != null
			and base_shape != null,
			"Every solid town prop must expose a reusable base collider."
		)
		assert(
			base_shape.size.y <= sprite.texture.get_height() * 0.2,
			"Town prop collision may cover only the lower ground-contact strip."
		)
		var collider_bottom := collision.position.y + base_shape.size.y * 0.5
		assert(
			collider_bottom >= -4.0 and collider_bottom <= 4.0,
			"Town prop collider must terminate at the sprite's ground baseline."
		)
	assert(town.has_node("AmbientLight"), "Town must expose ambient day/night tint.")
	assert(
		town.has_node("DayNightEnvironment"),
		"Town must connect to the global day/night cycle."
	)
	assert(
		town.has_node("EnvironmentFX/GoldenLeaves"),
		"Town must include animated autumn leaves."
	)
	var leaves := town.get_node(
		"EnvironmentFX/GoldenLeaves"
	) as GPUParticles2D
	var leaf_material := leaves.process_material as ParticleProcessMaterial
	assert(
		leaves.position == Vector2(800.0, 560.0)
		and leaves.amount <= 96
		and leaves.amount >= 72,
		"Town leaves must use a mobile-conscious emitter centered on the map."
	)
	assert(
		leaf_material != null
		and leaf_material.emission_shape
		== ParticleProcessMaterial.EMISSION_SHAPE_BOX
		and leaf_material.emission_box_extents.x >= 800.0
		and leaf_material.emission_box_extents.y >= 560.0,
		"Autumn leaves must spawn across the complete town, not a top strip."
	)
	assert(
		leaves.visibility_rect.position.x <= -896.0
		and leaves.visibility_rect.position.y <= -656.0
		and leaves.visibility_rect.end.x >= 896.0
		and leaves.visibility_rect.end.y >= 656.0,
		"Leaf visibility bounds must contain the full map around the emitter."
	)
	var town_tree := town.get_node("World/TownTree00/Sprite") as Sprite2D
	assert(
		town_tree != null
		and town_tree.material is ShaderMaterial
		and (town_tree.material as ShaderMaterial).shader != null,
		"Town foliage must use the reusable wind shader."
	)

	for location_name: String in EXPECTED_LOCATIONS:
		var marker := town.get_named_location(StringName(location_name))
		assert(marker != null, "Missing NPC schedule marker: " + location_name)
		assert(
			town.get_named_location_position(StringName(location_name)) != Vector2.INF,
			"Named location must resolve to a world position."
		)

	var navigation := town.get_navigation_region()
	assert(navigation != null, "Town must contain NavigationRegion2D.")
	assert(
		navigation.navigation_polygon != null
		and navigation.navigation_polygon.get_polygon_count() == 7,
		"Walkable navigation must cover both river banks and the bridge."
	)
	var bridge_path := NavigationServer2D.map_get_path(
		navigation.get_navigation_map(),
		Vector2(1120.0, 544.0),
		Vector2(1408.0, 544.0),
		true
	)
	assert(
		bridge_path.size() >= 2,
		"NPC navigation must connect both river banks across the stone bridge."
	)
	var north_bank_path := NavigationServer2D.map_get_path(
		navigation.get_navigation_map(),
		Vector2(1120.0, 256.0),
		Vector2(1408.0, 256.0),
		true
	)
	var north_path_uses_bridge := false
	for path_point: Vector2 in north_bank_path:
		if (
			path_point.x >= 1134.0
			and path_point.x <= 1362.0
			and path_point.y >= 496.0
			and path_point.y <= 592.0
		):
			north_path_uses_bridge = true
			break
	assert(
		north_path_uses_bridge,
		"Navigation crossing from the north banks must route through the bridge."
	)

	var player := town.get_node_or_null("World/Iven") as Node2D
	var camera := town.get_node_or_null("HLDCamera2D") as HLDCamera2D
	var dialogue := town.get_node_or_null("DialoguePanel") as DialoguePanel
	var mobile_controls := town.get_node_or_null(
		"MobileControls"
	) as MobileControls
	assert(player != null, "Iven must spawn at PlayerSpawn.")
	assert(camera != null, "Town must use the shared hybrid camera.")
	assert(dialogue != null, "Town must carry the shared dialogue UI.")
	assert(
		mobile_controls != null
		and mobile_controls.get_bound_player() == player,
		"Town mobile controls must bind to Iven at runtime."
	)
	assert(
		mobile_controls.interact_requested.is_connected(
			Callable(player, "request_interaction")
		),
		"Town touch interaction must route through Iven's interactable contract."
	)
	mobile_controls.move_input_changed.emit(Vector2(0.25, -0.75))
	assert(
		player.mobile_move_input == Vector2(0.25, -0.75),
		"Town touch joystick must drive Iven in two dimensions."
	)
	mobile_controls.move_input_changed.emit(Vector2.ZERO)
	assert(
		camera.world_rect == Rect2(0, 0, 1600, 1120),
		"Camera must be clamped to the complete town."
	)

	var lights := get_nodes_in_group(&"day_night_lights")
	assert(lights.size() >= 20, "Town must expose lamps, windows, and torches to DayNightCycle.")
	var torches := get_nodes_in_group(&"town_torch")
	assert(torches.size() == 5, "Important town entrances must have five lightweight torches.")
	for torch_node in torches:
		var torch := torch_node as Node2D
		assert(
			torch != null
			and torch.has_node("Flame")
			and torch.has_node("FlameCore")
			and torch.has_node("WarmLight"),
			"Each torch needs a procedural flame marker and managed point light."
		)
	var environment := town.get_node("DayNightEnvironment") as DayNightEnvironment
	assert(
		environment.get_managed_light_count() == lights.size(),
		"DayNightEnvironment must control every town lamp and lit window."
	)
	for light_node in lights:
		assert(light_node is PointLight2D, "Day/night light group may only contain PointLight2D.")
		assert(not (light_node as PointLight2D).enabled, "Town lights start disabled in daytime.")

	var scheduled_npcs := get_nodes_in_group(&"scheduled_npc")
	assert(
		scheduled_npcs.size() == 6,
		"Vierth must contain all six autonomous scheduled residents."
	)
	for npc in scheduled_npcs:
		var scheduled_npc := npc as ScheduledNPC
		assert(
			scheduled_npc.get_schedule_entry_count() >= 5,
			"Every scheduled resident needs a complete daily routine."
		)
		assert(
			scheduled_npc.get_named_location_count() >= 19,
			"Every resident must resolve the town schedule locations."
		)
		assert(
			scheduled_npc.get_current_location_id()
			== EXPECTED_0800_NPC_LOCATIONS[scheduled_npc.npc_id],
			"Residents must enter the scene at the location matching world time."
		)

	var atlas_file := FileAccess.open(
		"res://assets/tilesets/vierth_town_atlas.json",
		FileAccess.READ
	)
	assert(atlas_file != null, "Town atlas metadata must exist.")
	var atlas_metadata: Variant = JSON.parse_string(atlas_file.get_as_text())
	assert(atlas_metadata is Dictionary, "Town atlas metadata must be valid JSON.")
	assert(
		int((atlas_metadata as Dictionary).get("pixels_per_world_unit", 0)) == 1,
		"Town atlas must declare native 1:1 pixel density."
	)
	assert(
		not bool((atlas_metadata as Dictionary).get("resampled", true)),
		"Town terrain pipeline must not resample its source pixels."
	)

	print("Vierth Town scene test: PASS")
	town.queue_free()
	await process_frame
	quit(0)
