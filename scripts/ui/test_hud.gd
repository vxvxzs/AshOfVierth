extends CanvasLayer

@onready var kills_label: Label = $MarginContainer/PanelContainer/VBoxContainer/KillsLabel
@onready var light_label: Label = $MarginContainer/PanelContainer/VBoxContainer/LightLabel
@onready var objective_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ObjectiveLabel
@onready var health_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HealthLabel
@onready var world_label: Label = $MarginContainer/PanelContainer/VBoxContainer/WorldLabel

var player_health := 3
var player_max_health := 3

func _ready() -> void:
	ProgressionManager.echo_kills_changed.connect(_refresh)
	ProgressionManager.light_points_changed.connect(_refresh)
	ProgressionManager.reward_granted.connect(_on_reward_granted)
	ProgressionManager.death_registered.connect(_refresh)
	ProgressionManager.objective_changed.connect(_on_objective_changed)
	call_deferred("_bind_player_health")
	_refresh()

func _bind_player_health() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.health.health_changed.connect(_on_player_health_changed)
		player_health = player.health.current_health
		player_max_health = player.health.MAX_HEALTH
		_refresh()

func _refresh(_unused_value: int = 0) -> void:
	kills_label.text = "Echoes defeated: %d / %d" % [min(ProgressionManager.echo_kills, ProgressionManager.ECHO_KILLS_FOR_FIRST_REWARD), ProgressionManager.ECHO_KILLS_FOR_FIRST_REWARD]
	light_label.text = "Light: %d" % ProgressionManager.light_points
	objective_label.text = ProgressionManager.current_objective
	health_label.text = "Health: %d / %d" % [player_health, player_max_health]
	world_label.text = "World memory: %s" % ProgressionManager.get_world_memory_state()

func _on_reward_granted(amount: int) -> void:
	objective_label.text = "+%d Light." % amount

func _on_objective_changed(new_objective: String) -> void:
	objective_label.text = new_objective

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	player_health = current_health
	player_max_health = max_health
	_refresh()
