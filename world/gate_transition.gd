class_name GateTransition
extends Area2D

@export_file("*.tscn") var target_scene := "res://scenes/levels/VierthTown.tscn"

var _transition_started := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _transition_started or not body.is_in_group("player"):
		return
	if not ResourceLoader.exists(target_scene):
		push_warning("GateTransition target is not available yet: " + target_scene)
		return
	var scene_director := get_node_or_null("/root/SceneDirector")
	if scene_director == null or not scene_director.has_method("change_scene"):
		push_error("GateTransition requires the SceneDirector autoload.")
		return
	_transition_started = true
	monitoring = false
	scene_director.call("change_scene", target_scene)
