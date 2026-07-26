extends SceneTree

const BLUEPRINT_PATH := "res://data/levels/vierth_town_blueprint.json"
const ATLAS_PATH := "res://assets/tilesets/vierth_town_atlas.png"
const GROUND_PATH := "res://assets/tilesets/vierth_town_ground.png"
const TILESET_PATH := "res://assets/tilesets/vierth_town_tileset.tres"
const SCENE_PATH := "res://scenes/levels/VierthTown.tscn"
const ENVIRONMENT_PATH := "res://assets/environment/town/"
const GOLDEN_LEAF_PATH := (
	"res://assets/environment/entrance/golden_leaf.svg"
)
const FOLIAGE_WIND_SHADER_PATH := "res://shaders/foliage_wind.gdshader"
const LEVEL_SCRIPT := preload("res://scripts/levels/vierth_town.gd")
const CAMERA_SCRIPT := preload("res://scripts/camera/hld_camera_2d.gd")
const DAY_NIGHT_ENVIRONMENT_SCRIPT := preload(
	"res://scripts/world/day_night_environment.gd"
)
const SCHEDULED_NPC_SCENE := preload(
	"res://scenes/npcs/ScheduledNPC.tscn"
)
const DIALOGUE_UI_SCENE := preload(
	"res://scenes/dialogue/DialogueUI.tscn"
)
const MOBILE_CONTROLS_SCENE := preload(
	"res://scenes/ui/MobileControls.tscn"
)
const WELL_BASE_SIZE := Vector2(44.0, 20.0)
const WELL_BASE_OFFSET := Vector2(0.0, -8.0)
const STALL_BASE_SIZE := Vector2(76.0, 14.0)
const STALL_BASE_OFFSET := Vector2(0.0, -6.0)
const LAMP_BASE_SIZE := Vector2(12.0, 10.0)
const LAMP_BASE_OFFSET := Vector2(0.0, -4.0)


func _init() -> void:
	var blueprint := _load_blueprint()
	if blueprint.is_empty():
		quit(1)
		return
	var tile_set := _build_tileset()
	if tile_set == null or ResourceSaver.save(tile_set, TILESET_PATH) != OK:
		push_error("Could not save the Vierth town TileSet.")
		quit(1)
		return
	var scene_root := _build_scene(blueprint)
	if scene_root == null:
		quit(1)
		return
	var packed := PackedScene.new()
	if packed.pack(scene_root) != OK or ResourceSaver.save(packed, SCENE_PATH) != OK:
		push_error("Could not save VierthTown scene.")
		scene_root.free()
		quit(1)
		return
	scene_root.free()
	print("Built: ", TILESET_PATH)
	print("Built: ", SCENE_PATH)
	quit(0)


func _load_blueprint() -> Dictionary:
	var file := FileAccess.open(BLUEPRINT_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing Vierth town blueprint.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Vierth town blueprint is not a JSON object.")
		return {}
	return parsed as Dictionary


func _build_tileset() -> TileSet:
	var atlas_texture := load(ATLAS_PATH) as Texture2D
	if atlas_texture == null:
		push_error("Vierth town atlas has not been imported.")
		return null
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	for tile_id in range(8):
		source.create_tile(Vector2i(tile_id % 4, tile_id / 4))
	return tile_set


func _build_scene(blueprint: Dictionary) -> Node2D:
	var tile_size := int(blueprint["tile_size"])
	var map_size := _vector2i(blueprint["map_size"])
	var world_size := Vector2(map_size * tile_size)
	var ground_texture := load(GROUND_PATH) as Texture2D
	if ground_texture == null:
		push_error("Vierth town ground has not been imported.")
		return null

	var root := Node2D.new()
	root.name = "VierthTown"
	root.set_script(LEVEL_SCRIPT)

	var ground_layer := Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -100
	root.add_child(ground_layer)
	ground_layer.owner = root
	var ground := Sprite2D.new()
	ground.name = "ContinuousGround"
	ground.centered = false
	ground.texture = ground_texture
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_layer.add_child(ground)
	ground.owner = root

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	root.add_child(world)
	world.owner = root

	_build_town_square(world, blueprint, tile_size, root)
	_build_landmark_buildings(world, blueprint, tile_size, root)
	_build_river_and_bridge(world, blueprint, tile_size, world_size, root)
	_build_trees(world, blueprint, tile_size, root)
	_build_lamps(world, blueprint, tile_size, root)
	_build_torches(world, blueprint, tile_size, root)
	_build_named_locations(root, blueprint, tile_size)
	_build_navigation(root, blueprint, tile_size, world_size)
	_build_scheduled_npcs(world, blueprint, root)
	_build_player_spawn(root, blueprint, tile_size)
	_build_camera(root, blueprint, world_size)
	_build_day_night_environment(root)
	_build_environment_fx(root, world_size)
	_build_gameplay_ui(root)
	return root


func _build_gameplay_ui(root: Node2D) -> void:
	var dialogue_panel := DIALOGUE_UI_SCENE.instantiate()
	dialogue_panel.name = "DialoguePanel"
	root.add_child(dialogue_panel)
	dialogue_panel.owner = root

	var mobile_controls := MOBILE_CONTROLS_SCENE.instantiate()
	mobile_controls.name = "MobileControls"
	root.add_child(mobile_controls)
	mobile_controls.owner = root


func _build_town_square(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	owner: Node
) -> void:
	var square_position := (
		_vector2(blueprint["landmarks"]["TownSquare"]) * tile_size
	)
	var square := Node2D.new()
	square.name = "TownSquare"
	square.position = square_position
	# Nested y-sort is required: otherwise the complete market is treated as
	# one canvas item and Iven cannot pass naturally behind individual stalls.
	square.y_sort_enabled = true
	world.add_child(square)
	square.owner = owner

	var well := _create_prop(
		"Well",
		ENVIRONMENT_PATH + "well.png",
		Vector2.ZERO,
		owner,
		WELL_BASE_SIZE,
		WELL_BASE_OFFSET
	)
	square.add_child(well)
	well.owner = owner
	_assign_owner_recursive(well, owner)

	var stall_index := 0
	for stall_entry: Array in blueprint.get("stalls", []):
		var stall_position := _vector2(stall_entry) * tile_size - square_position
		var color_name := String(stall_entry[2])
		var stall := _create_prop(
			"MarketStall%02d" % stall_index,
			ENVIRONMENT_PATH + "stall_%s.png" % color_name,
			stall_position,
			owner,
			STALL_BASE_SIZE,
			STALL_BASE_OFFSET
		)
		square.add_child(stall)
		stall.owner = owner
		_assign_owner_recursive(stall, owner)
		stall_index += 1


func _build_landmark_buildings(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	owner: Node
) -> void:
	for building_data: Dictionary in blueprint.get("buildings", []):
		var building_name := String(building_data["name"])
		var building := _create_prop(
			building_name,
			ENVIRONMENT_PATH + String(building_data["asset"]),
			_vector2(building_data["position"]) * tile_size,
			owner,
			_vector2(building_data["collision_size"]),
			_vector2(building_data["collision_offset"])
		)
		world.add_child(building)
		building.owner = owner
		_assign_owner_recursive(building, owner)
		if building_name == "ElianBakery":
			_add_bakery_details(building, owner)
		elif building_name == "Tavern":
			var porch := Marker2D.new()
			porch.name = "Porch"
			porch.position = Vector2(0, 12)
			building.add_child(porch)
			porch.owner = owner
		_add_window_light(building, owner, Vector2(-54, -50))
		_add_window_light(building, owner, Vector2(54, -50))


func _add_bakery_details(building: Node2D, owner: Node) -> void:
	var sign_marker := Marker2D.new()
	sign_marker.name = "BakerySign"
	sign_marker.position = Vector2(88, -66)
	building.add_child(sign_marker)
	sign_marker.owner = owner

	var smoke_material := ParticleProcessMaterial.new()
	smoke_material.direction = Vector3(0, -1, 0)
	smoke_material.spread = 18.0
	smoke_material.initial_velocity_min = 7.0
	smoke_material.initial_velocity_max = 13.0
	smoke_material.gravity = Vector3(3.0, -1.5, 0.0)
	smoke_material.scale_min = 2.0
	smoke_material.scale_max = 5.0
	smoke_material.color = Color(0.55, 0.55, 0.52, 0.42)
	var smoke := GPUParticles2D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = Vector2(66, -158)
	smoke.amount = 18
	smoke.lifetime = 4.2
	smoke.randomness = 0.45
	smoke.process_material = smoke_material
	building.add_child(smoke)
	smoke.owner = owner
	_add_window_light(building, owner, Vector2(-52, -48))
	_add_window_light(building, owner, Vector2(52, -48))


func _build_river_and_bridge(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	world_size: Vector2,
	owner: Node
) -> void:
	var terrain: Dictionary = blueprint["terrain"]
	var river_half_width := (
		float(terrain["river"]["half_width"]) * tile_size + 18.0
	)
	var bridge_y := float(terrain["bridge_y"]) * tile_size
	var bridge_clearance_half_height := 72.0
	var river := Node2D.new()
	river.name = "River"
	river.position = _vector2(blueprint["landmarks"]["River"]) * tile_size
	world.add_child(river)
	river.owner = owner
	var river_marker := Marker2D.new()
	river_marker.name = "RiverCenter"
	river.add_child(river_marker)
	river_marker.owner = owner

	# The painted river is not walkable. Two colliders leave one deliberate
	# opening aligned to the stone bridge, so gameplay and navigation agree.
	var north_end := bridge_y - bridge_clearance_half_height
	_add_river_blocker(
		river,
		"RiverBlockNorth",
		Vector2(0.0, north_end * 0.5 - river.position.y),
		Vector2(river_half_width * 2.0, north_end),
		owner
	)
	var south_start := bridge_y + bridge_clearance_half_height
	_add_river_blocker(
		river,
		"RiverBlockSouth",
		Vector2(
			0.0,
			(south_start + world_size.y) * 0.5 - river.position.y
		),
		Vector2(river_half_width * 2.0, world_size.y - south_start),
		owner
	)

	var bridge_position := _vector2(blueprint["landmarks"]["StoneBridge"]) * tile_size
	var bridge := _create_prop(
		"StoneBridge",
		ENVIRONMENT_PATH + "stone_bridge.png",
		bridge_position + Vector2(0, 64),
		owner,
		Vector2.ZERO,
		Vector2.ZERO
	)
	# The deck is always rendered over the baked river and under characters.
	# It has no collider; only the two river blockers define the shoreline.
	bridge.z_index = -1
	bridge.add_to_group(&"bridge_deck", true)
	world.add_child(bridge)
	bridge.owner = owner
	_assign_owner_recursive(bridge, owner)


func _add_river_blocker(
	river: Node2D,
	node_name: String,
	local_position: Vector2,
	size: Vector2,
	owner: Node
) -> void:
	var blocker := StaticBody2D.new()
	blocker.name = node_name
	blocker.position = local_position.round()
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	blocker.add_to_group(&"river_blocker", true)
	river.add_child(blocker)
	blocker.owner = owner

	var shape := RectangleShape2D.new()
	shape.size = size.round()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	blocker.add_child(collision)
	collision.owner = owner


func _build_trees(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	owner: Node
) -> void:
	var index := 0
	for tree_data: Array in blueprint.get("trees", []):
		var tree := _create_prop(
			"TownTree%02d" % index,
			ENVIRONMENT_PATH + "autumn_tree.png",
			_vector2(tree_data) * tile_size,
			owner,
			Vector2(28, 20),
			Vector2(0, -10)
		)
		world.add_child(tree)
		tree.owner = owner
		_assign_owner_recursive(tree, owner)
		var sprite := tree.get_node_or_null("Sprite") as Sprite2D
		var wind_shader := load(
			FOLIAGE_WIND_SHADER_PATH
		) as Shader
		if sprite != null and wind_shader != null:
			var wind_material := ShaderMaterial.new()
			wind_material.shader = wind_shader
			wind_material.set_shader_parameter(
				"wind_strength",
				0.75 + float(index % 4) * 0.08
			)
			sprite.material = wind_material
		index += 1


func _build_lamps(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	owner: Node
) -> void:
	var index := 0
	for lamp_data: Array in blueprint.get("lamps", []):
		var lamp := _create_prop(
			"StreetLamp%02d" % index,
			ENVIRONMENT_PATH + "street_lamp.png",
			_vector2(lamp_data) * tile_size,
			owner,
			LAMP_BASE_SIZE,
			LAMP_BASE_OFFSET
		)
		world.add_child(lamp)
		lamp.owner = owner
		_assign_owner_recursive(lamp, owner)
		_add_window_light(lamp, owner, Vector2(0, -61))
		index += 1


func _build_torches(
	world: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	owner: Node
) -> void:
	for torch_data: Dictionary in blueprint.get("torches", []):
		var torch := Node2D.new()
		torch.name = String(torch_data["name"])
		torch.position = (_vector2(torch_data["position"]) * tile_size).round()
		torch.add_to_group(&"town_torch", true)
		world.add_child(torch)
		torch.owner = owner

		# A tiny procedural flame marker is cheaper than another bitmap and
		# remains crisp under nearest-neighbour rendering.
		var outer_flame := Polygon2D.new()
		outer_flame.name = "Flame"
		outer_flame.position = Vector2(0.0, -24.0)
		outer_flame.polygon = PackedVector2Array([
			Vector2(0.0, -9.0),
			Vector2(6.0, 1.0),
			Vector2(3.0, 8.0),
			Vector2(-3.0, 8.0),
			Vector2(-6.0, 1.0),
		])
		outer_flame.color = Color("ed8a3a")
		torch.add_child(outer_flame)
		outer_flame.owner = owner

		var inner_flame := Polygon2D.new()
		inner_flame.name = "FlameCore"
		inner_flame.position = Vector2(0.0, -21.0)
		inner_flame.polygon = PackedVector2Array([
			Vector2(0.0, -5.0),
			Vector2(3.0, 1.0),
			Vector2(0.0, 5.0),
			Vector2(-3.0, 1.0),
		])
		inner_flame.color = Color("ffe29a")
		torch.add_child(inner_flame)
		inner_flame.owner = owner

		_add_window_light(torch, owner, Vector2(0.0, -23.0))


func _add_window_light(parent: Node2D, owner: Node, position: Vector2) -> void:
	var light_texture := load(ENVIRONMENT_PATH + "town_light.png") as Texture2D
	var light := PointLight2D.new()
	light.name = "WarmLight"
	light.position = position
	light.texture = light_texture
	light.texture_scale = 2.2
	light.energy = 0.85
	light.color = Color("ffd083")
	light.enabled = false
	light.add_to_group(&"day_night_lights", true)
	parent.add_child(light)
	light.owner = owner


func _build_named_locations(root: Node2D, blueprint: Dictionary, tile_size: int) -> void:
	var locations := Node2D.new()
	locations.name = "NamedLocations"
	root.add_child(locations)
	locations.owner = root
	var location_data: Dictionary = blueprint["named_locations"]
	for location_name: String in location_data:
		var marker := Marker2D.new()
		marker.name = location_name
		marker.position = _vector2(location_data[location_name]) * tile_size
		locations.add_child(marker)
		marker.owner = root


func _build_scheduled_npcs(
	world: Node2D,
	blueprint: Dictionary,
	owner: Node
) -> void:
	for npc_data: Dictionary in blueprint.get("scheduled_npcs", []):
		var npc := SCHEDULED_NPC_SCENE.instantiate() as ScheduledNPC
		var npc_id := String(npc_data["id"])
		npc.name = npc_id.to_pascal_case()
		npc.npc_id = StringName(npc_id)
		npc.display_name = String(npc_data["display_name"])
		npc.schedule_path = (
			"res://data/npcs/" + String(npc_data["schedule"])
		)
		npc.location_root_path = NodePath("../../NamedLocations")
		var body := npc.get_node_or_null("Body") as Polygon2D
		if body != null:
			body.color = Color(String(npc_data.get("color", "756558")))
		world.add_child(npc)
		npc.owner = owner


func _build_day_night_environment(root: Node2D) -> void:
	var ambient := CanvasModulate.new()
	ambient.name = "AmbientLight"
	ambient.color = Color.WHITE
	root.add_child(ambient)
	ambient.owner = root

	var environment := Node.new()
	environment.name = "DayNightEnvironment"
	environment.set_script(DAY_NIGHT_ENVIRONMENT_SCRIPT)
	environment.set(
		"canvas_modulate_path",
		NodePath("../AmbientLight")
	)
	environment.set("lights_root_path", NodePath("../World"))
	environment.set("auto_discover_group", false)
	root.add_child(environment)
	environment.owner = root


func _build_environment_fx(root: Node2D, world_size: Vector2) -> void:
	var leaf_texture := load(GOLDEN_LEAF_PATH) as Texture2D
	if leaf_texture == null:
		push_warning("Town leaves are missing: " + GOLDEN_LEAF_PATH)
		return
	var fx := Node2D.new()
	fx.name = "EnvironmentFX"
	root.add_child(fx)
	fx.owner = root

	var leaves := GPUParticles2D.new()
	leaves.name = "GoldenLeaves"
	leaves.position = world_size * 0.5
	leaves.z_index = 45
	leaves.amount = 96
	leaves.lifetime = 11.0
	leaves.preprocess = 11.0
	leaves.randomness = 0.72
	leaves.texture = leaf_texture
	leaves.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaves.visibility_rect = Rect2(
		-world_size * 0.5 - Vector2(96.0, 96.0),
		world_size + Vector2(192.0, 192.0)
	)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(
		world_size.x * 0.5,
		world_size.y * 0.5,
		1.0
	)
	material.direction = Vector3(-0.14, 1.0, 0.0)
	material.spread = 28.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 21.0
	material.gravity = Vector3(6.0, 4.0, 0.0)
	material.angular_velocity_min = -65.0
	material.angular_velocity_max = 65.0
	material.scale_min = 0.65
	material.scale_max = 1.2
	leaves.process_material = material
	fx.add_child(leaves)
	leaves.owner = root


func _build_navigation(
	root: Node2D,
	blueprint: Dictionary,
	tile_size: int,
	world_size: Vector2
) -> void:
	var terrain: Dictionary = blueprint["terrain"]
	var river_center := float(terrain["river"]["center_x"]) * tile_size
	var river_half := float(terrain["river"]["half_width"]) * tile_size + 18.0
	var bridge_y := float(terrain["bridge_y"]) * tile_size
	var left_end := river_center - river_half
	var right_start := river_center + river_half
	var bridge_top := bridge_y - 48.0
	var bridge_bottom := bridge_y + 48.0
	var world_right := world_size.x - 8.0
	var world_bottom := world_size.y - 8.0
	var vertices := PackedVector2Array([
		Vector2(8, 8),
		Vector2(left_end, 8),
		Vector2(right_start, 8),
		Vector2(world_right, 8),
		Vector2(8, bridge_top),
		Vector2(left_end, bridge_top),
		Vector2(right_start, bridge_top),
		Vector2(world_right, bridge_top),
		Vector2(8, bridge_bottom),
		Vector2(left_end, bridge_bottom),
		Vector2(right_start, bridge_bottom),
		Vector2(world_right, bridge_bottom),
		Vector2(8, world_bottom),
		Vector2(left_end, world_bottom),
		Vector2(right_start, world_bottom),
		Vector2(world_right, world_bottom),
	])
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.vertices = vertices
	# Seven exact rectangles share complete edges. This is more reliable than
	# overlapping polygons and guarantees that both banks connect only through
	# the bridge corridor.
	navigation_polygon.add_polygon(PackedInt32Array([0, 1, 5, 4]))
	navigation_polygon.add_polygon(PackedInt32Array([4, 5, 9, 8]))
	navigation_polygon.add_polygon(PackedInt32Array([8, 9, 13, 12]))
	navigation_polygon.add_polygon(PackedInt32Array([2, 3, 7, 6]))
	navigation_polygon.add_polygon(PackedInt32Array([6, 7, 11, 10]))
	navigation_polygon.add_polygon(PackedInt32Array([10, 11, 15, 14]))
	navigation_polygon.add_polygon(PackedInt32Array([5, 6, 10, 9]))
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	region.navigation_polygon = navigation_polygon
	root.add_child(region)
	region.owner = root


func _build_player_spawn(root: Node2D, blueprint: Dictionary, tile_size: int) -> void:
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = _vector2(blueprint["player_spawn"]) * tile_size
	root.add_child(spawn)
	spawn.owner = root


func _build_camera(root: Node2D, blueprint: Dictionary, world_size: Vector2) -> void:
	var camera_data: Dictionary = blueprint["camera"]
	var camera := Camera2D.new()
	camera.name = "HLDCamera2D"
	camera.set_script(CAMERA_SCRIPT)
	camera.target_path = NodePath("../World/Iven")
	camera.world_rect = Rect2(Vector2.ZERO, world_size)
	camera.deadzone_size = _vector2(camera_data["deadzone_size"])
	camera.follow_speed = float(camera_data["follow_speed"])
	camera.transition_duration = float(camera_data["transition_duration"])
	camera.pixel_snap_enabled = true
	var zoom := float(camera_data["zoom"])
	camera.zoom = Vector2(zoom, zoom)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	root.add_child(camera)
	camera.owner = root


func _create_prop(
	node_name: String,
	texture_path: String,
	position: Vector2,
	owner: Node,
	collision_size: Vector2,
	collision_offset: Vector2
) -> StaticBody2D:
	var prop := StaticBody2D.new()
	prop.name = node_name
	prop.position = position.round()
	prop.collision_layer = 1
	prop.collision_mask = 1
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Missing town prop: " + texture_path)
		return prop
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -texture.get_height() * 0.5)
	prop.add_child(sprite)
	if collision_size.x > 0.0 and collision_size.y > 0.0:
		var shape := RectangleShape2D.new()
		shape.size = collision_size
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.position = collision_offset
		collision.shape = shape
		prop.add_child(collision)
		prop.add_to_group(&"ground_base_collider", true)
	return prop


func _assign_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_assign_owner_recursive(child, scene_owner)


func _vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


func _vector2i(values: Array) -> Vector2i:
	return Vector2i(int(values[0]), int(values[1]))
