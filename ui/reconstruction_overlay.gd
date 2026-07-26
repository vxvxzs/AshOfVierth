class_name ReconstructionOverlay
extends CanvasLayer

signal reconstruction_finished

const DISPLAY_TIME := 1.25

@onready var root: Control = $Root
var time_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()

func show_reconstruction() -> void:
	time_left = DISPLAY_TIME
	root.modulate.a = 1.0
	root.show()
	get_tree().paused = true

func _process(delta: float) -> void:
	if not root.visible:
		return
	time_left -= delta
	root.modulate.a = clampf(time_left / DISPLAY_TIME + 0.15, 0.0, 1.0)
	if time_left <= 0.0:
		root.hide()
		get_tree().paused = false
		reconstruction_finished.emit()
