extends CanvasLayer

signal closed

@onready var root: Control = $Root
@onready var item_name: Label = $Root/CenterContainer/PanelContainer/VBoxContainer/ItemName
@onready var item_description: Label = $Root/CenterContainer/PanelContainer/VBoxContainer/Description

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()

func open_item(title: String, description: String) -> void:
	item_name.text = title
	item_description.text = description
	root.show()
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_close()
	elif event is InputEventMouseButton and event.pressed:
		_close()
	elif event is InputEventScreenTouch and event.pressed:
		_close()

func _close() -> void:
	root.hide()
	get_tree().paused = false
	closed.emit()
