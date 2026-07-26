class_name MobileControls
extends CanvasLayer

signal move_input_changed(direction: Vector2)
signal attack_requested
signal short_step_requested
signal parry_requested
signal interact_requested
signal step_swipe_requested

@onready var joystick = $Root/VirtualJoystick
@onready var attack_button = $Root/AttackButton
@onready var step_button = $Root/StepButton
@onready var parry_button = $Root/ParryButton
@onready var interact_button = $Root/InteractButton

const STEP_SWIPE_MIN_DISTANCE := 65.0
const STEP_SWIPE_RIGHT_SCREEN_START := 0.55

var step_swipe_enabled := false
var swipe_start := Vector2.ZERO
var swipe_pointer := -1
var _bound_player: Node
var _exploration_mode := false

func _ready() -> void:
	visible = _is_mobile_platform()
	joystick.input_changed.connect(move_input_changed.emit)
	attack_button.activated.connect(attack_requested.emit)
	step_button.activated.connect(short_step_requested.emit)
	parry_button.activated.connect(parry_requested.emit)
	interact_button.activated.connect(interact_requested.emit)
	var progression_manager := get_node_or_null("/root/ProgressionManager")
	if progression_manager != null:
		progression_manager.connect(
			"ability_unlocked",
			_on_ability_unlocked
		)
		step_button.visible = bool(
			progression_manager.call(
				"is_ability_unlocked",
				&"short_step"
			)
		)
	else:
		step_button.hide()
	interact_button.hide()

func bind_player(player: Node) -> void:
	if _bound_player == player:
		return
	unbind_player()
	_bound_player = player
	if _bound_player == null:
		return
	move_input_changed.connect(
		Callable(_bound_player, "set_mobile_move_input")
	)
	attack_requested.connect(
		Callable(_bound_player, "request_light_attack")
	)
	short_step_requested.connect(
		Callable(_bound_player, "request_short_step")
	)
	parry_requested.connect(Callable(_bound_player, "request_parry"))
	interact_requested.connect(
		Callable(_bound_player, "request_interaction")
	)

func unbind_player() -> void:
	if _bound_player == null:
		return
	if not is_instance_valid(_bound_player):
		_bound_player = null
		return
	var bindings := [
		[
			move_input_changed,
			Callable(_bound_player, "set_mobile_move_input"),
		],
		[
			attack_requested,
			Callable(_bound_player, "request_light_attack"),
		],
		[
			short_step_requested,
			Callable(_bound_player, "request_short_step"),
		],
		[
			parry_requested,
			Callable(_bound_player, "request_parry"),
		],
		[
			interact_requested,
			Callable(_bound_player, "request_interaction"),
		],
	]
	for binding: Array in bindings:
		var source_signal: Signal = binding[0]
		var callable: Callable = binding[1]
		if source_signal.is_connected(callable):
			source_signal.disconnect(callable)
	_bound_player.set_mobile_move_input(Vector2.ZERO)
	_bound_player = null

func get_bound_player() -> Node:
	return _bound_player

func _exit_tree() -> void:
	unbind_player()

func set_exploration_mode(is_enabled: bool) -> void:
	_exploration_mode = is_enabled
	var progression_manager := get_node_or_null("/root/ProgressionManager")
	var step_is_unlocked := (
		progression_manager != null
		and bool(
			progression_manager.call(
				"is_ability_unlocked",
				&"short_step"
			)
		)
	)
	attack_button.visible = not is_enabled
	parry_button.visible = not is_enabled
	step_button.visible = not is_enabled and step_is_unlocked
	interact_button.visible = is_enabled

func set_prologue_actions(step_is_available: bool, interact_is_available: bool = false) -> void:
	attack_button.hide()
	parry_button.hide()
	step_button.visible = step_is_available and not _is_mobile_platform()
	interact_button.visible = interact_is_available
	step_swipe_enabled = step_is_available and _is_mobile_platform()

func _unhandled_input(event: InputEvent) -> void:
	if not step_swipe_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x >= get_viewport().get_visible_rect().size.x * STEP_SWIPE_RIGHT_SCREEN_START:
			swipe_start = event.position
			swipe_pointer = event.index
		elif not event.pressed and event.index == swipe_pointer:
			var upward_distance: float = swipe_start.y - event.position.y
			if upward_distance >= STEP_SWIPE_MIN_DISTANCE:
				step_swipe_requested.emit()
			swipe_pointer = -1

func _on_ability_unlocked(ability_id: StringName) -> void:
	if ability_id == &"short_step" and not _exploration_mode:
		step_button.show()

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
