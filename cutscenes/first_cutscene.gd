extends Control

const VIERTH_ENTRANCE_SCENE := "res://scenes/levels/VierthEntrance.tscn"

@onready var video: VideoStreamPlayer = $Video

var _leaving := false

func _ready() -> void:
	video.finished.connect(_on_video_finished)
	video.play()

func _on_video_finished() -> void:
	if _leaving:
		return
	_leaving = true
	# SceneDirector owns the closing fade, so the video ends cleanly before the
	# prototype arrival scene is shown.
	SceneDirector.change_scene(VIERTH_ENTRANCE_SCENE)
