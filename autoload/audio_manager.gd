extends Node

var ambience_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	ambience_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	add_child(ambience_player)
	add_child(sfx_player)

func play_bakery_ambience() -> void:
	_play_if_available(ambience_player, "res://assets/audio/bakery_musicbox_oven.ogg", -18.0)

func mute_bakery_ambience() -> void:
	if ambience_player.playing:
		var fade := create_tween()
		fade.tween_property(ambience_player, "volume_db", -80.0, 0.12)

func resume_bakery_ambience() -> void:
	if ambience_player.stream != null:
		var fade := create_tween()
		fade.tween_property(ambience_player, "volume_db", -18.0, 0.4)

func play_water_splash() -> void:
	_play_if_available(sfx_player, "res://assets/audio/sfx_water_splash.ogg", -8.0)

func _play_if_available(player: AudioStreamPlayer, resource_path: String, volume_db: float) -> void:
	if not ResourceLoader.exists(resource_path):
		return
	player.stream = load(resource_path)
	player.volume_db = volume_db
	player.play()
