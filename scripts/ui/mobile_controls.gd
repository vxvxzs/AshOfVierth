class_name MobileControls
extends CanvasLayer

signal move_input_changed(direction: Vector2)
signal attack_requested
signal short_step_requested

@onready var joystick = $Root/VirtualJoystick
@onready var attack_button = $Root/AttackButton
@onready var step_button = $Root/StepButton

func _ready() -> void:
	visible = _is_mobile_platform()
	joystick.input_changed.connect(move_input_changed.emit)
	attack_button.activated.connect(attack_requested.emit)
	step_button.activated.connect(short_step_requested.emit)
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	step_button.visible = ProgressionManager.is_ability_unlocked(&"short_step")

func _on_ability_unlocked(ability_id: StringName) -> void:
	if ability_id == &"short_step":
		step_button.show()

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
