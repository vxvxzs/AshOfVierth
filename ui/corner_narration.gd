class_name CornerNarration
extends CanvasLayer

signal sequence_finished

const LINE_DURATION := 3.4

@onready var panel: Control = $MarginContainer/PanelContainer
@onready var speaker_label: Label = $MarginContainer/PanelContainer/VBoxContainer/Speaker
@onready var text_label: Label = $MarginContainer/PanelContainer/VBoxContainer/Text

var lines: Array[Dictionary] = []
var line_index := -1
var time_left := 0.0

func _ready() -> void:
	panel.hide()

func play_sequence(new_lines: Array) -> void:
	lines.clear()
	for line in new_lines:
		lines.append(line)
	line_index = -1
	_next_line()

func _process(delta: float) -> void:
	if line_index < 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		_next_line()

func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		line_index = -1
		panel.hide()
		sequence_finished.emit()
		return
	var line := lines[line_index]
	speaker_label.visible = true
	speaker_label.text = String(line.get("speaker", "Spirit"))
	text_label.text = String(line.get("text", ""))
	time_left = float(line.get("duration", LINE_DURATION))
	panel.show()
