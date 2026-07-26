extends SceneTree

const FRAME_DELTA := 1.0 / 60.0

func _init() -> void:
	var movement = load("res://scripts/player/components/player_movement.gd").new()
	var body := CharacterBody2D.new()
	root.add_child(body)
	root.add_child(movement)
	_test_acceleration(movement, body)
	_test_friction(movement, body)
	_test_turning(movement, body)
	_test_analogue_input(movement, body)
	body.free()
	movement.free()
	print("PLAYER_MOVEMENT_TEST: PASS")
	quit(0)

func _test_acceleration(movement: Node, body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	movement.update_velocity(body, Vector2.RIGHT, 1.0, FRAME_DELTA)
	assert(body.velocity.x > 0.0 and body.velocity.x < movement.max_speed)
	for frame in range(120):
		movement.update_velocity(body, Vector2.RIGHT, 1.0, FRAME_DELTA)
	assert(is_equal_approx(body.velocity.x, movement.max_speed))
	assert(movement.max_speed < 185.0)

func _test_friction(movement: Node, body: CharacterBody2D) -> void:
	body.velocity = Vector2(movement.max_speed, 0.0)
	movement.update_velocity(body, Vector2.ZERO, 1.0, FRAME_DELTA)
	assert(body.velocity.x > 0.0 and body.velocity.x < movement.max_speed)
	for frame in range(30):
		movement.update_velocity(body, Vector2.ZERO, 1.0, FRAME_DELTA)
	assert(body.velocity.is_zero_approx())

func _test_turning(movement: Node, body: CharacterBody2D) -> void:
	body.velocity = Vector2(movement.max_speed, 0.0)
	for frame in range(20):
		movement.update_velocity(body, Vector2.LEFT, 1.0, FRAME_DELTA)
	assert(body.velocity.x < 0.0)

func _test_analogue_input(movement: Node, body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	for frame in range(120):
		movement.update_velocity(body, Vector2(0.5, 0.0), 1.0, FRAME_DELTA)
	assert(is_equal_approx(body.velocity.x, movement.max_speed * 0.5))
