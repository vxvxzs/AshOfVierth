extends Node2D

const PLAYER_SCENE_PATH := "res://scenes/player/Player.tscn"


func _enter_tree() -> void:
	var actors := get_node_or_null("World")
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	if actors == null or spawn == null or actors.has_node("Iven"):
		return
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("VierthEntrance could not load the Player scene.")
		return
	var player := player_scene.instantiate() as Node2D
	player.name = "Iven"
	player.global_position = spawn.global_position
	actors.add_child(player)


func _ready() -> void:
	var player := get_node_or_null("World/Iven")
	var mobile_controls := get_node_or_null("MobileControls") as MobileControls
	if player == null or mobile_controls == null:
		push_error("VierthEntrance requires Iven and MobileControls.")
		return
	mobile_controls.bind_player(player)
	mobile_controls.set_exploration_mode(true)
