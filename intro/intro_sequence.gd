extends Control

const RETURN_JOURNEY_SCENE := "res://scenes/intro/ReturnJourney.tscn"

@onready var arrival_label: Label = $CenterContainer/Arrival

func _ready() -> void:
	play_arrival()

func play_arrival() -> void:
	arrival_label.modulate.a = 0.0
	var sequence := create_tween()
	sequence.tween_property(arrival_label, "modulate:a", 1.0, 1.0)
	sequence.tween_interval(2.25)
	sequence.tween_property(arrival_label, "modulate:a", 0.0, 1.0)
	await sequence.finished
	SceneDirector.change_scene(RETURN_JOURNEY_SCENE)
