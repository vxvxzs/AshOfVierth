class_name VierthGateNPC
extends StaticBody2D

enum State {
	AMBIENT,
	PLAYER_NEARBY,
	DIALOGUE,
}

const DIALOGUE_RESOLVER = preload(
	"res://scripts/dialogue/dialogue_resolver.gd"
)

@export var display_name := "Villager":
	set(value):
		display_name = value
		if is_node_ready():
			_update_label()
@export var robe_color := Color("657d69"):
	set(value):
		robe_color = value
		if is_node_ready():
			_update_color()
@export var dialogue_id: StringName = &"vierth_gate"
@export var companion_path: NodePath
@export var ambient_lines := PackedStringArray(["Quiet morning."])
@export_range(2.0, 12.0, 0.1) var ambient_interval := 6.0
@export_range(0.0, 10.0, 0.1) var ambient_phase := 0.5
@export_range(0.5, 5.0, 0.1) var bubble_duration := 2.4

@onready var body_visual: Polygon2D = $Body
@onready var head_visual: Polygon2D = $Head
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_panel: Control = $PromptPanel
@onready var prompt_label: Label = $PromptPanel/Prompt
@onready var speech_bubble: Control = $SpeechBubble
@onready var speech_label: Label = $SpeechBubble/Text

var state := State.AMBIENT
var _nearby_player: Node2D
var _dialogue_target: Node2D
var _ambient_countdown := 0.0
var _bubble_time_left := 0.0
var _ambient_line_index := 0


func _ready() -> void:
	add_to_group(&"player_interactable")
	_update_label()
	_update_color()
	ambient_phase = maxf(ambient_phase, 0.1)
	_ambient_countdown = ambient_phase
	prompt_panel.hide()
	speech_bubble.hide()
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)
	interaction_area.input_event.connect(_on_interaction_input_event)


func _process(delta: float) -> void:
	if state != State.AMBIENT:
		return
	_ambient_countdown -= delta
	if _bubble_time_left > 0.0:
		_bubble_time_left -= delta
		if _bubble_time_left <= 0.0:
			speech_bubble.hide()
	if _ambient_countdown <= 0.0:
		_show_next_ambient_line()
		_ambient_countdown = ambient_interval


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYER_NEARBY or _dialogue_is_open():
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_E, KEY_F]
	):
		_start_main_dialogue()
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_A
	):
		_start_main_dialogue()
		get_viewport().set_input_as_handled()


func set_companion(new_companion_path: NodePath) -> void:
	companion_path = new_companion_path

func can_interact(player: Node2D) -> bool:
	return (
		state == State.PLAYER_NEARBY
		and _nearby_player == player
		and not _dialogue_is_open()
	)

func interact(player: Node2D) -> void:
	if can_interact(player):
		_start_main_dialogue()


func enter_dialogue_state(player: Node2D) -> void:
	state = State.DIALOGUE
	_dialogue_target = player
	prompt_panel.hide()
	speech_bubble.hide()
	_face_player(player)


func leave_dialogue_state() -> void:
	_restore_default_facing()
	_dialogue_target = null
	if _nearby_player != null:
		state = State.PLAYER_NEARBY
		prompt_panel.show()
	else:
		state = State.AMBIENT
		_ambient_countdown = 0.8


func get_state_name() -> StringName:
	return StringName(String(State.keys()[state]).to_lower())


func _on_player_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_nearby_player = body
	if state == State.DIALOGUE:
		return
	state = State.PLAYER_NEARBY
	speech_bubble.hide()
	prompt_label.text = (
		"Tap to talk"
		if _is_mobile_platform()
		else "E / F  Talk"
	)
	prompt_panel.show()


func _on_player_exited(body: Node2D) -> void:
	if body != _nearby_player:
		return
	_nearby_player = null
	prompt_panel.hide()
	if state != State.DIALOGUE:
		state = State.AMBIENT
		_ambient_countdown = 0.8


func _on_interaction_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
) -> void:
	if state != State.PLAYER_NEARBY or _dialogue_is_open():
		return
	var pressed: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	) or (
		event is InputEventScreenTouch
		and event.pressed
	)
	if pressed:
		_start_main_dialogue()
		get_viewport().set_input_as_handled()


func _start_main_dialogue() -> void:
	if _nearby_player == null:
		return
	var dialogue_panel := get_tree().get_first_node_in_group(
		&"dialogue_panel"
	)
	if dialogue_panel == null:
		push_warning("%s: DialoguePanel is missing." % display_name)
		return
	var dialogue := DIALOGUE_RESOLVER.get_dialogue(String(dialogue_id))
	if dialogue.is_empty():
		return

	enter_dialogue_state(_nearby_player)
	var companion := _get_companion()
	if companion != null:
		companion.enter_dialogue_state(_nearby_player)
	var camera := _get_hybrid_camera()
	if camera != null:
		camera.set_custom_target(self)
	dialogue_panel.dialogue_finished.connect(
		_on_main_dialogue_finished,
		CONNECT_ONE_SHOT
	)
	dialogue_panel.open_dialogue(dialogue)


func _on_main_dialogue_finished() -> void:
	var camera := _get_hybrid_camera()
	if camera != null:
		camera.clear_custom_target(true)
	leave_dialogue_state()
	var companion := _get_companion()
	if companion != null:
		companion.leave_dialogue_state()


func _show_next_ambient_line() -> void:
	if ambient_lines.is_empty():
		return
	speech_label.text = ambient_lines[_ambient_line_index]
	_ambient_line_index = (
		_ambient_line_index + 1
	) % ambient_lines.size()
	speech_bubble.show()
	_bubble_time_left = bubble_duration


func _get_companion() -> VierthGateNPC:
	if companion_path.is_empty():
		return null
	return get_node_or_null(companion_path) as VierthGateNPC


func _get_hybrid_camera() -> HLDCamera2D:
	return get_tree().get_first_node_in_group(
		&"hybrid_camera"
	) as HLDCamera2D


func _face_player(player: Node2D) -> void:
	var facing_sign := -1.0 if player.global_position.x < global_position.x else 1.0
	body_visual.scale.x = facing_sign
	head_visual.scale.x = facing_sign


func _restore_default_facing() -> void:
	body_visual.scale.x = 1.0
	head_visual.scale.x = 1.0


func _dialogue_is_open() -> bool:
	var dialogue_panel := get_tree().get_first_node_in_group(
		&"dialogue_panel"
	)
	return dialogue_panel != null and dialogue_panel.is_open()


func _update_label() -> void:
	$Name.text = display_name


func _update_color() -> void:
	$Body.color = robe_color


func _is_mobile_platform() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("ios")
		or OS.has_feature("android")
	)
