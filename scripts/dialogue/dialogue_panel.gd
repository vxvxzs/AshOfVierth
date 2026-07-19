class_name DialoguePanel
extends CanvasLayer

signal dialogue_finished

@onready var speaker_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SpeakerLabel
@onready var body_label: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyLabel
@onready var continue_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ContinueLabel

var lines: Array = []
var current_line_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func open_dialogue(new_lines: Array) -> void:
	if new_lines.is_empty():
		return
	lines = new_lines
	current_line_index = 0
	show()
	get_tree().paused = true
	_render_current_line()

func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			advance()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close_dialogue()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	current_line_index += 1
	if current_line_index >= lines.size():
		close_dialogue()
		return
	_render_current_line()

func close_dialogue() -> void:
	hide()
	lines.clear()
	get_tree().paused = false
	dialogue_finished.emit()

func _render_current_line() -> void:
	var line: Dictionary = lines[current_line_index]
	speaker_label.text = str(line.get("speaker", "Unknown"))
	body_label.text = str(line.get("text", ""))
	continue_label.text = "Tap or press E to continue"
