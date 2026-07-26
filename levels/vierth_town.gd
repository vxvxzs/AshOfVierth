class_name VierthTown
extends Node2D

const PLAYER_SCENE_PATH := "res://scenes/player/Player.tscn"

@onready var world: Node2D = $World
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var named_locations: Node2D = $NamedLocations


func _enter_tree() -> void:
	var actors := get_node_or_null("World") as Node2D
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	if actors == null or spawn == null or actors.has_node("Iven"):
		return
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("VierthTown could not load the Player scene.")
		return
	var player := player_scene.instantiate() as Node2D
	player.name = "Iven"
	player.global_position = spawn.global_position
	actors.add_child(player)


func _ready() -> void:
	var player := get_node_or_null("World/Iven")
	var mobile_controls := get_node_or_null("MobileControls") as MobileControls
	if player == null or mobile_controls == null:
		push_error("VierthTown requires Iven and MobileControls.")
		return
	mobile_controls.bind_player(player)
	mobile_controls.set_exploration_mode(true)


func get_named_location(location_id: StringName) -> Marker2D:
	if named_locations == null:
		return null
	return named_locations.get_node_or_null(NodePath(String(location_id))) as Marker2D


func get_named_location_position(location_id: StringName) -> Vector2:
	var marker := get_named_location(location_id)
	return marker.global_position if marker != null else Vector2.INF


func get_navigation_region() -> NavigationRegion2D:
	return get_node_or_null("NavigationRegion2D") as NavigationRegion2D
