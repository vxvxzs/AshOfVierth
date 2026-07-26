extends SceneTree

const BLUEPRINT_PATH := "res://data/levels/vierth_entrance_blueprint.json"
const ATLAS_PATH := "res://assets/tilesets/vierth_atlas.png"
const GROUND_PATH := "res://assets/tilesets/vierth_ground.png"
const TILESET_PATH := "res://assets/tilesets/vierth_tileset.tres"
const SCENE_PATH := "res://scenes/levels/VierthEntrance.tscn"
const STONE_GATE_PATH := (
	"res://assets/environment/entrance/vierth_stone_gate.svg"
)
const GOLDEN_LEAF_PATH := (
	"res://assets/environment/entrance/golden_leaf.svg"
)
const FOLIAGE_WIND_SHADER_PATH := "res://shaders/foliage_wind.gdshader"
const NPC_SCENE := preload("res://scenes/npcs/VierthGateNPC.tscn")
const DIALOGUE_UI_SCENE := preload(
	"res://scenes/dialogue/DialogueUI.tscn"
)
const MOBILE_CONTROLS_SCENE := preload(
	"res://scenes/ui/MobileControls.tscn"
)
const CAMERA_SCRIPT := preload("res://scripts/camera/hld_camera_2d.gd")
const CAMERA_ZONE_SCRIPT := preload(
	"res://scripts/camera/camera_zone_2d.gd"
)
const LEVEL_SCRIPT := preload("res://scripts/levels/vierth_entrance.gd")
const GATE_TRANSITION_SCRIPT := preload(
	"res://scripts/world/gate_transition.gd"
)

const OBJECT_PATHS := {
	8: "res://assets/tilesets/vierth_objects/autumn_shrub.png",
	9: "res://assets/tilesets/vierth_objects/autumn_tree.png",
	10: "res://assets/tilesets/vierth_objects/mossy_rock.png",
	11: "res://assets/tilesets/vierth_objects/tree_stump.png",
	12: "res://assets/tilesets/vierth_objects/fence_horizontal.png",
	13: "res://assets/tilesets/vierth_objects/fence_vertical.png",
	14: "res://assets/tilesets/vierth_objects/fence_corner.png",
	15: "res://assets/tilesets/vierth_objects/entrance_sign.png",
}
const OBJECT_NAMES := {
	8: "Shrub",
	9: "Tree",
	10: "Rock",
	11: "Stump",
	12: "FenceHorizontal",
	13: "FenceVertical",
	14: "FenceCorner",
	15: "EntranceSign",
}
const COLLISION_SIZES := {
	8: Vector2(38, 15),
	9: Vector2(20, 16),
	10: Vector2(42, 25),
	11: Vector2(28, 18),
	12: Vector2(84, 14),
	13: Vector2(18, 52),
	14: Vector2(62, 20),
	15: Vector2(18, 24),
}

var _foliage_material: ShaderMaterial


func _init() -> void:
	var blueprint := _load_blueprint()
	if blueprint.is_empty():
		quit(1)
		return
	var tile_set := _build_tileset()
	if tile_set == null or ResourceSaver.save(tile_set, TILESET_PATH) != OK:
		push_error("Could not save Vierth TileSet.")
		quit(1)
		return
	var root := _build_scene(blueprint)
	if root == null:
		quit(1)
		return
	var packed_scene := PackedScene.new()
	if packed_scene.pack(root) != OK or ResourceSaver.save(packed_scene, SCENE_PATH) != OK:
		push_error("Could not save VierthEntrance scene.")
		root.free()
		quit(1)
		return
	root.free()
	print("Built: ", TILESET_PATH)
	print("Built: ", SCENE_PATH)
	quit()


func _load_blueprint() -> Dictionary:
	var file := FileAccess.open(BLUEPRINT_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing blueprint: " + BLUEPRINT_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid blueprint JSON.")
		return {}
	return parsed as Dictionary


func _build_tileset() -> TileSet:
	var atlas_texture := load(ATLAS_PATH) as Texture2D
	if atlas_texture == null:
		push_error("Atlas has not been imported: " + ATLAS_PATH)
		return null
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	for tile_id in range(8):
		source.create_tile(_atlas_coords(tile_id))
	return tile_set


func _build_scene(blueprint: Dictionary) -> Node2D:
	var map_size := _vector2i_from_array(blueprint["map_size"])
	var tile_size := int(blueprint["tile_size"])
	var map_pixel_size := Vector2(map_size * tile_size)
	var ground_texture := load(GROUND_PATH) as Texture2D
	if ground_texture == null:
		push_error("Ground texture has not been imported: " + GROUND_PATH)
		return null

	var root := Node2D.new()
	root.name = "VierthEntrance"
	root.set_script(LEVEL_SCRIPT)
	_foliage_material = ShaderMaterial.new()
	_foliage_material.shader = load(FOLIAGE_WIND_SHADER_PATH) as Shader
	_foliage_material.set_shader_parameter("wind_strength", 1.15)
	_foliage_material.set_shader_parameter("wind_speed", 1.15)
	_foliage_material.set_shader_parameter("gust_strength", 0.35)
	_foliage_material.set_shader_parameter("anchored_portion", 0.28)

	var ground_layer := Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -100
	root.add_child(ground_layer)
	ground_layer.owner = root

	var ground := Sprite2D.new()
	ground.name = "ContinuousGround"
	ground.texture = ground_texture
	ground.centered = false
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_layer.add_child(ground)
	ground.owner = root

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	root.add_child(world)
	world.owner = root

	_fill_forest(world, blueprint, map_size, tile_size, root)
	_create_city_gate(world, blueprint["city_gate"], tile_size, root)
	_place_blueprint_objects(
		world,
		blueprint.get("landmarks", []),
		tile_size,
		root
	)

	var npc_nodes := {}
	for npc_data: Dictionary in blueprint.get("npcs", []):
		var npc := NPC_SCENE.instantiate() as VierthGateNPC
		npc.name = String(npc_data["name"])
		npc.display_name = String(npc_data["display_name"])
		npc.robe_color = Color(String(npc_data["color"]))
		npc.dialogue_id = StringName(
			npc_data.get("dialogue_id", "vierth_gate")
		)
		npc.ambient_phase = float(
			npc_data.get("ambient_phase", 0.5)
		)
		npc.ambient_lines = PackedStringArray(
			npc_data.get("ambient_lines", [])
		)
		npc.position = (
			_vector2_from_array(npc_data["position"]) * float(tile_size)
		).round()
		world.add_child(npc)
		npc.owner = root
		npc_nodes[npc.name] = npc

	for npc_data: Dictionary in blueprint.get("npcs", []):
		var npc_name := String(npc_data["name"])
		var companion_name := String(npc_data.get("companion", ""))
		if (
			npc_nodes.has(npc_name)
			and npc_nodes.has(companion_name)
		):
			var npc: VierthGateNPC = npc_nodes[npc_name]
			var companion: VierthGateNPC = npc_nodes[companion_name]
			npc.set_companion(npc.get_path_to(companion))

	var player_spawn := _vector2_from_array(blueprint["player_spawn"])
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = player_spawn * float(tile_size)
	root.add_child(spawn)
	spawn.owner = root

	var camera_data: Dictionary = blueprint["camera"]
	var camera := Camera2D.new()
	camera.name = "HLDCamera2D"
	camera.set_script(CAMERA_SCRIPT)
	camera.target_path = NodePath("../World/Iven")
	camera.world_rect = Rect2(Vector2.ZERO, map_pixel_size)
	camera.deadzone_size = _vector2_from_array(
		camera_data.get("deadzone_size", [88.0, 56.0])
	)
	camera.follow_speed = float(
		camera_data.get("follow_speed", 9.0)
	)
	camera.transition_duration = float(camera_data["transition_duration"])
	camera.pixel_snap_enabled = true
	var camera_zoom := float(camera_data["zoom"])
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_pixel_size.x)
	camera.limit_bottom = int(map_pixel_size.y)
	root.add_child(camera)
	camera.owner = root

	_create_camera_zones(
		root,
		blueprint.get("camera_zones", []),
		root
	)
	_create_gate_transition(root, blueprint["city_gate"], root)
	_create_environment_fx(root, map_pixel_size, root)

	var interface := CanvasLayer.new()
	interface.name = "Interface"
	root.add_child(interface)
	interface.owner = root

	var entrance_label := Label.new()
	entrance_label.name = "LocationLabel"
	entrance_label.position = Vector2(22, 18)
	entrance_label.text = "VIERTH - SOUTHERN ENTRANCE"
	entrance_label.add_theme_font_size_override("font_size", 14)
	entrance_label.add_theme_color_override("font_color", Color("e9d9b4"))
	entrance_label.add_theme_color_override(
		"font_shadow_color",
		Color(0, 0, 0, 0.8)
	)
	entrance_label.add_theme_constant_override("shadow_offset_x", 2)
	entrance_label.add_theme_constant_override("shadow_offset_y", 2)
	interface.add_child(entrance_label)
	entrance_label.owner = root

	var dialogue_panel := DIALOGUE_UI_SCENE.instantiate()
	dialogue_panel.name = "DialoguePanel"
	root.add_child(dialogue_panel)
	dialogue_panel.owner = root

	var mobile_controls := MOBILE_CONTROLS_SCENE.instantiate()
	mobile_controls.name = "MobileControls"
	root.add_child(mobile_controls)
	mobile_controls.owner = root

	return root


func _create_camera_zones(
	parent: Node2D,
	zone_entries: Array,
	scene_owner: Node
) -> void:
	for entry: Dictionary in zone_entries:
		var trigger := _rect2_from_array(entry["trigger"])
		var bounds := _rect2_from_array(entry["bounds"])
		var zone := Area2D.new()
		zone.name = "%sCameraZone" % String(entry["id"]).to_pascal_case()
		zone.set_script(CAMERA_ZONE_SCRIPT)
		zone.collision_layer = 0
		zone.collision_mask = 1
		zone.set("zone_id", StringName(entry["id"]))
		zone.set("camera_bounds", bounds)
		zone.set(
			"transition_focus",
			_vector2_from_array(entry["focus"])
		)
		parent.add_child(zone)
		zone.owner = scene_owner

		var shape_resource := RectangleShape2D.new()
		shape_resource.size = trigger.size
		var collision := CollisionShape2D.new()
		collision.name = "Trigger"
		collision.position = trigger.get_center()
		collision.shape = shape_resource
		zone.add_child(collision)
		collision.owner = scene_owner


func _create_city_gate(
	world: Node2D,
	gate_data: Dictionary,
	tile_size: int,
	scene_owner: Node
) -> void:
	var texture := load(STONE_GATE_PATH) as Texture2D
	if texture == null:
		push_error("Missing Vierth stone gate texture: " + STONE_GATE_PATH)
		return

	var origin := (
		_vector2_from_array(gate_data["origin"]) * float(tile_size)
	).round()
	var gate_root := Node2D.new()
	gate_root.name = "VierthCityGate"
	gate_root.position = origin
	world.add_child(gate_root)
	gate_root.owner = scene_owner

	var sprite := Sprite2D.new()
	sprite.name = "StoneWallAndGate"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(-480.0, -origin.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gate_root.add_child(sprite)
	sprite.owner = scene_owner

	# The two collision wings leave a broad, readable passage below the arch.
	_create_wall_collision(
		gate_root,
		"WestWallCollision",
		Vector2(-260.0, 3.0),
		Vector2(440.0, 44.0),
		scene_owner
	)
	_create_wall_collision(
		gate_root,
		"EastWallCollision",
		Vector2(310.0, 3.0),
		Vector2(340.0, 44.0),
		scene_owner
	)


func _create_wall_collision(
	parent: Node2D,
	node_name: String,
	local_position: Vector2,
	size: Vector2,
	scene_owner: Node
) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = local_position
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	body.owner = scene_owner

	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_owner


func _create_gate_transition(
	parent: Node2D,
	gate_data: Dictionary,
	scene_owner: Node
) -> void:
	var trigger_rect := _rect2_from_array(gate_data["transition_rect"])
	var transition := Area2D.new()
	transition.name = "TownGateTransition"
	transition.set_script(GATE_TRANSITION_SCRIPT)
	transition.collision_layer = 0
	transition.collision_mask = 1
	transition.set(
		"target_scene",
		String(gate_data["target_scene"])
	)
	parent.add_child(transition)
	transition.owner = scene_owner

	var shape := RectangleShape2D.new()
	shape.size = trigger_rect.size
	var collision := CollisionShape2D.new()
	collision.name = "Trigger"
	collision.position = trigger_rect.get_center()
	collision.shape = shape
	transition.add_child(collision)
	collision.owner = scene_owner


func _create_environment_fx(
	parent: Node2D,
	map_pixel_size: Vector2,
	scene_owner: Node
) -> void:
	var leaf_texture := load(GOLDEN_LEAF_PATH) as Texture2D
	if leaf_texture == null:
		push_warning("Missing golden leaf texture: " + GOLDEN_LEAF_PATH)
		return

	var environment_fx := Node2D.new()
	environment_fx.name = "EnvironmentFX"
	parent.add_child(environment_fx)
	environment_fx.owner = scene_owner

	var leaves := GPUParticles2D.new()
	leaves.name = "GoldenLeaves"
	leaves.position = Vector2(map_pixel_size.x * 0.5, -12.0)
	leaves.z_index = 40
	leaves.amount = 76
	leaves.lifetime = 10.0
	leaves.preprocess = 10.0
	leaves.randomness = 0.65
	leaves.texture = leaf_texture
	leaves.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaves.visibility_rect = Rect2(
		-map_pixel_size.x * 0.5,
		-64.0,
		map_pixel_size.x,
		map_pixel_size.y + 128.0
	)

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_BOX
	)
	process_material.emission_box_extents = Vector3(
		map_pixel_size.x * 0.5,
		12.0,
		1.0
	)
	process_material.direction = Vector3(-0.18, 1.0, 0.0)
	process_material.spread = 24.0
	process_material.initial_velocity_min = 12.0
	process_material.initial_velocity_max = 24.0
	process_material.gravity = Vector3(7.0, 5.0, 0.0)
	process_material.angular_velocity_min = -75.0
	process_material.angular_velocity_max = 75.0
	process_material.scale_min = 0.75
	process_material.scale_max = 1.35
	leaves.process_material = process_material
	environment_fx.add_child(leaves)
	leaves.owner = scene_owner


func _fill_forest(
	world: Node2D,
	blueprint: Dictionary,
	map_size: Vector2i,
	tile_size: int,
	scene_owner: Node
) -> void:
	var map_pixel_size := Vector2(map_size * tile_size)
	var seed_value := int(blueprint["forest_seed"])
	var density := float(blueprint["forest_density"])
	var road_centers: Array = blueprint["road_centers"]
	var road_half_width := (
		float(blueprint["road_half_width"]) + 0.65
	) * tile_size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var object_index := 0

	for base_y in range(42, int(map_pixel_size.y) - 12, 58):
		for base_x in range(34, int(map_pixel_size.x) - 18, 62):
			var position := Vector2(
				base_x + rng.randf_range(-17.0, 17.0),
				base_y + rng.randf_range(-13.0, 13.0)
			)
			var road_center := _road_center_at_y(
				position.y,
				road_centers,
				tile_size
			)
			if absf(position.x - road_center) < road_half_width + 34.0:
				continue
			var edge_boost := (
				0.28
				if position.x < 130.0
				or position.x > map_pixel_size.x - 130.0
				else 0.0
			)
			if rng.randf() > minf(0.90, density + edge_boost):
				continue
			var roll := rng.randf()
			var object_id := 9
			if roll < 0.24:
				object_id = 8
			elif roll < 0.38:
				object_id = 10
			elif roll < 0.47:
				object_id = 11
			_create_object(
				world,
				object_id,
				position,
				object_index,
				scene_owner
			)
			object_index += 1


func _road_center_at_y(
	world_y: float,
	road_centers: Array,
	tile_size: int
) -> float:
	var row_position := clampf(
		world_y / tile_size,
		0.0,
		float(road_centers.size() - 1)
	)
	var row_a := floori(row_position)
	var row_b := mini(road_centers.size() - 1, row_a + 1)
	var weight := row_position - row_a
	var tile_center := lerpf(
		float(road_centers[row_a]),
		float(road_centers[row_b]),
		weight
	)
	return (tile_center + 0.5) * tile_size


func _place_blueprint_objects(
	world: Node2D,
	entries: Array,
	tile_size: int,
	scene_owner: Node
) -> void:
	var index := 0
	for entry: Array in entries:
		var position := Vector2(
			(float(entry[0]) + 0.5) * tile_size,
			(float(entry[1]) + 1.0) * tile_size
		)
		_create_object(
			world,
			int(entry[2]),
			position,
			index,
			scene_owner
		)
		index += 1


func _create_object(
	world: Node2D,
	object_id: int,
	position: Vector2,
	index: int,
	scene_owner: Node
) -> void:
	if not OBJECT_PATHS.has(object_id):
		return
	var texture := load(String(OBJECT_PATHS[object_id])) as Texture2D
	if texture == null:
		push_warning("Missing object texture: " + String(OBJECT_PATHS[object_id]))
		return

	var body := StaticBody2D.new()
	body.name = "%s_%03d" % [String(OBJECT_NAMES[object_id]), index]
	body.position = position.round()
	body.collision_layer = 1
	body.collision_mask = 1
	world.add_child(body)
	body.owner = scene_owner

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2(0.0, -float(texture.get_height()) * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if object_id == 8 or object_id == 9:
		sprite.material = _foliage_material
	body.add_child(sprite)
	sprite.owner = scene_owner

	var collision_size: Vector2 = COLLISION_SIZES[object_id]
	var shape := RectangleShape2D.new()
	shape.size = collision_size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = Vector2(0.0, -collision_size.y * 0.5)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_owner


func _atlas_coords(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % 4, tile_id / 4)


func _vector2i_from_array(values: Array) -> Vector2i:
	return Vector2i(int(values[0]), int(values[1]))


func _vector2_from_array(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


func _rect2_from_array(values: Array) -> Rect2:
	return Rect2(
		float(values[0]),
		float(values[1]),
		float(values[2]),
		float(values[3])
	)
