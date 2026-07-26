extends SceneTree

const LEVEL_PATH := "res://scenes/levels/VierthEntrance.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_state := root.get_node("/root/WorldState")
	world_state.reset_runtime_state()
	var memory_manager := root.get_node("/root/DialogueManager")
	memory_manager.reset_runtime_state()
	var packed_level := load(LEVEL_PATH) as PackedScene
	assert(packed_level != null, "Vierth Entrance scene must load.")
	var level := packed_level.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var player := level.get_node("World/Iven") as Node2D
	var oren := level.get_node("World/Oren") as VierthGateNPC
	var mira := level.get_node("World/Mira") as VierthGateNPC
	var camera := level.get_node("HLDCamera2D") as HLDCamera2D
	var dialogue := level.get_node("DialoguePanel") as DialoguePanel
	var mobile_controls := level.get_node("MobileControls") as MobileControls
	var gate := level.get_node("World/VierthCityGate/StoneWallAndGate") as Sprite2D
	var transition := level.get_node("TownGateTransition") as GateTransition
	var leaves := level.get_node("EnvironmentFX/GoldenLeaves") as GPUParticles2D
	var foliage := level.get_node("World/Tree_004/Sprite") as Sprite2D
	assert(player != null, "Iven must spawn.")
	assert(oren != null and mira != null, "Both gate NPCs must exist.")
	assert(camera != null, "Hybrid camera must exist.")
	assert(dialogue != null, "Dialogue panel must exist.")
	assert(
		mobile_controls != null
		and mobile_controls.get_bound_player() == player,
		"Entrance mobile controls must bind to Iven at runtime."
	)
	mobile_controls.move_input_changed.emit(Vector2.RIGHT)
	assert(
		player.mobile_move_input == Vector2.RIGHT,
		"Touch joystick input must reach Iven."
	)
	mobile_controls.move_input_changed.emit(Vector2.ZERO)
	assert(gate != null and gate.texture != null, "Vierth must use the stone city gate.")
	assert(
		level.has_node("World/VierthCityGate/WestWallCollision")
		and level.has_node("World/VierthCityGate/EastWallCollision"),
		"The city gate must be flanked by solid stone walls."
	)
	assert(
		transition != null
		and transition.target_scene == "res://scenes/levels/VierthTown.tscn",
		"The open gate must route into the complete Vierth town scene."
	)
	assert(leaves != null and leaves.emitting, "The entrance needs falling autumn leaves.")
	assert(
		foliage != null
		and foliage.material is ShaderMaterial
		and (foliage.material as ShaderMaterial).shader != null,
		"Entrance foliage must use the reusable wind shader."
	)

	player.global_position = Vector2(730.0, 180.0)
	camera.enter_zone(
		&"test_gate",
		Rect2(0.0, 0.0, 960.0, 360.0),
		Vector2(80.0, 80.0),
		0.1
	)
	assert(camera.is_transitioning(), "Camera zone must begin an eased pan.")
	for _frame in range(6):
		camera._process(0.02)
	assert(
		not camera.is_transitioning(),
		"Camera must resume following after the zone pan."
	)
	assert(
		camera.global_position.distance_to(Vector2(640.0, 180.0)) < 2.0,
		"Zone transition must clamp around Iven, not jump to fixed zone focus."
	)

	player.global_position = oren.global_position + Vector2(16.0, 0.0)
	for _frame in range(3):
		await physics_frame
	assert(
		oren.get_state_name() == &"player_nearby",
		"Oren must detect the nearby player."
	)

	mobile_controls.interact_requested.emit()
	assert(dialogue.is_open(), "Interaction must open the shared dialogue UI.")
	assert(
		camera.get_custom_target() == oren,
		"Dialogue must temporarily focus the camera on the speaking NPC."
	)
	assert(
		oren.get_state_name() == &"dialogue"
		and mira.get_state_name() == &"dialogue",
		"Ambient chat must pause for both NPCs during main dialogue."
	)
	dialogue.advance()
	dialogue.advance()
	assert(
		dialogue.get_choice_count() == 3,
		"Gate dialogue must expose three Iven character choices."
	)
	dialogue.choose(0)
	assert(
		memory_manager.recall(
			&"gatekeepers",
			&"return_reason"
		) == "missed_vierth",
		"Selected dialogue answer must persist in NPC memory."
	)
	assert(
		dialogue.get_current_node_id() == "missed_oren",
		"Oren must enter the answer-specific response branch."
	)
	dialogue.close_dialogue()
	await process_frame
	assert(
		camera.get_custom_target() == null,
		"Closing dialogue must immediately clear camera custom_target."
	)
	assert(
		absf(camera.global_position.x - player.global_position.x) < 2.0,
		"Camera must return directly to Iven after dialogue."
	)
	assert(
		oren.get_state_name() == &"player_nearby",
		"Oren must return to proximity state after dialogue."
	)
	assert(
		mira.get_state_name() == &"ambient",
		"Mira must resume ambient state without showing a false prompt."
	)

	var remembered_dialogue := DialogueResolver.get_dialogue("vierth_gate")
	assert(
		remembered_dialogue.get("start", "") == "remembered",
		"Later conversations must resolve from the stored NPC memory."
	)

	print("Vierth Entrance systems test: PASS")
	quit(0)
