class_name QuestNotifier
extends CanvasLayer

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/CenterContainer/PanelContainer
@onready var objective_label: Label = $Root/CenterContainer/PanelContainer/VBoxContainer/Objective

var received_first_objective := false
var active_tween: Tween

func _ready() -> void:
	panel.hide()
	ProgressionManager.objective_changed.connect(_on_objective_changed)

func _on_objective_changed(objective: String) -> void:
	if not received_first_objective:
		received_first_objective = true
		return
	show_objective(objective)

func show_objective(objective: String) -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	objective_label.text = objective
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.94, 0.94)
	panel.show()
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.28)
	active_tween.tween_property(panel, "scale", Vector2.ONE, 0.28)
	active_tween.set_parallel(false)
	active_tween.tween_interval(2.5)
	active_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	active_tween.tween_callback(panel.hide)
