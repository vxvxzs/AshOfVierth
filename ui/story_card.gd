extends CanvasLayer

@onready var root: Control = $Root
@onready var text_label: Label = $Root/CenterContainer/PanelContainer/Text

func _ready() -> void:
	root.hide()

func show_card(text: String, hold_time: float = 2.6) -> void:
	text_label.text = text
	root.modulate.a = 0.0
	root.show()
	var sequence := create_tween()
	sequence.tween_property(root, "modulate:a", 1.0, 0.35)
	sequence.tween_interval(hold_time)
	sequence.tween_property(root, "modulate:a", 0.0, 0.45)
	sequence.tween_callback(root.hide)
