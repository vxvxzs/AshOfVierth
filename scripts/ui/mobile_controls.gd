class_name MobileControls
extends CanvasLayer

signal move_input_changed(direction: Vector2)
signal attack_requested
signal short_step_requested

@onready var joystick = $Root/VirtualJoystick
@onready var attack_button = $Root/AttackButton
@onready var step_button = $Root/StepButton

func _ready() -> void:
	joystick.input_changed.connect(move_input_changed.emit)
	attack_button.activated.connect(attack_requested.emit)
	step_button.activated.connect(short_step_requested.emit)
