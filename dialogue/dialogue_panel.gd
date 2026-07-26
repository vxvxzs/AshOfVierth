class_name DialoguePanel
extends CanvasLayer

signal dialogue_finished
signal choice_selected(choice_id: StringName, choice_text: String)

@onready var portrait_frame: Control = $MarginContainer/PanelContainer/DialogueRow/PortraitFrame
@onready var portrait_texture: TextureRect = $MarginContainer/PanelContainer/DialogueRow/PortraitFrame/Portrait
@onready var speaker_label: Label = $MarginContainer/PanelContainer/DialogueRow/Content/SpeakerLabel
@onready var body_label: Label = $MarginContainer/PanelContainer/DialogueRow/Content/BodyLabel
@onready var choices_container: VBoxContainer = $MarginContainer/PanelContainer/DialogueRow/Content/Choices
@onready var choice_style_template: Button = $MarginContainer/PanelContainer/DialogueRow/Content/Choices/ChoiceStyleTemplate
@onready var continue_label: Label = $MarginContainer/PanelContainer/DialogueRow/Content/ContinueLabel

var _dialogue: Dictionary = {}
var _nodes: Dictionary = {}
var _current_node_id := ""
var _choice_buttons: Array[Button] = []
var _selected_choice_index := -1
var _tree_was_paused := false
var _owns_tree_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func open_dialogue(dialogue_data: Variant) -> void:
	if visible or _owns_tree_pause:
		push_warning("DialoguePanel ignored a second dialogue while one is open.")
		return
	var normalized := _normalize_dialogue(dialogue_data)
	if normalized.is_empty():
		return
	_dialogue = normalized
	_nodes = Dictionary(_dialogue.get("nodes", {}))
	_current_node_id = String(_dialogue.get("start", ""))
	if _current_node_id.is_empty() or not _nodes.has(_current_node_id):
		return
	_tree_was_paused = get_tree().paused
	_owns_tree_pause = true
	show()
	get_tree().paused = true
	_render_current_node()


func is_open() -> bool:
	return visible


func get_choice_count() -> int:
	return _choice_buttons.size()


func get_current_node_id() -> String:
	return _current_node_id


func _input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventScreenTouch
		and event.pressed
		and _choice_buttons.is_empty()
	):
		advance()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not _choice_buttons.is_empty():
			if event.keycode == KEY_UP:
				_move_choice_selection(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_move_choice_selection(1)
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
				choose(_selected_choice_index)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				close_dialogue()
				get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			advance()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close_dialogue()
			get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and _choice_buttons.is_empty()
	):
		advance()
		get_viewport().set_input_as_handled()
func advance() -> void:
	if not visible or not _choice_buttons.is_empty():
		return
	var node := _get_current_node()
	_go_to_node(String(node.get("next", "")))


func choose(choice_index: int) -> void:
	var node := _get_current_node()
	var choices: Array = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	var memory_manager := get_node_or_null("/root/DialogueManager")
	if memory_manager != null:
		memory_manager.record_choice(choice)
	choice_selected.emit(
		StringName(choice.get("id", "")),
		String(choice.get("text", ""))
	)
	_go_to_node(String(choice.get("next", "")))


func close_dialogue() -> void:
	if not visible and not _owns_tree_pause:
		return
	_clear_choice_buttons()
	hide()
	_dialogue.clear()
	_nodes.clear()
	_current_node_id = ""
	_restore_tree_pause()
	dialogue_finished.emit()


func _exit_tree() -> void:
	_restore_tree_pause()


func _restore_tree_pause() -> void:
	if not _owns_tree_pause:
		return
	var tree := get_tree()
	if tree != null:
		tree.paused = _tree_was_paused
	_owns_tree_pause = false


func _render_current_node() -> void:
	var node := _get_current_node()
	if node.is_empty():
		close_dialogue()
		return
	speaker_label.text = String(node.get("speaker", "Unknown"))
	body_label.text = String(node.get("text", ""))
	_set_portrait(String(node.get("portrait", "")))
	_build_choices(Array(node.get("choices", [])))
	continue_label.visible = _choice_buttons.is_empty()
	continue_label.text = (
		"Tap to continue"
		if _is_mobile_platform()
		else "E / Space / click  Continue"
	)


func _build_choices(choices: Array) -> void:
	_clear_choice_buttons()
	choices_container.visible = not choices.is_empty()
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var button := Button.new()
		button.name = "Choice_%d" % index
		button.text = String(choice.get("text", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 18)
		for style_name: StringName in [
			&"normal",
			&"hover",
			&"pressed",
			&"focus",
		]:
			button.add_theme_stylebox_override(
				style_name,
				choice_style_template.get_theme_stylebox(style_name)
			)
		button.pressed.connect(choose.bind(index))
		choices_container.add_child(button)
		_choice_buttons.append(button)
	if not _choice_buttons.is_empty():
		_selected_choice_index = 0
		_choice_buttons[0].grab_focus()


func _move_choice_selection(direction: int) -> void:
	if _choice_buttons.is_empty():
		return
	_selected_choice_index = wrapi(
		_selected_choice_index + direction,
		0,
		_choice_buttons.size()
	)
	_choice_buttons[_selected_choice_index].grab_focus()


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			choices_container.remove_child(button)
			button.queue_free()
	_choice_buttons.clear()
	_selected_choice_index = -1
	if is_instance_valid(choices_container):
		choices_container.hide()


func _set_portrait(path: String) -> void:
	var texture: Texture2D
	if not path.is_empty():
		texture = load(path) as Texture2D
	portrait_texture.texture = texture
	portrait_frame.visible = texture != null


func _go_to_node(next_node_id: String) -> void:
	_clear_choice_buttons()
	if next_node_id.is_empty() or not _nodes.has(next_node_id):
		close_dialogue()
		return
	_current_node_id = next_node_id
	_render_current_node()


func _get_current_node() -> Dictionary:
	return Dictionary(_nodes.get(_current_node_id, {}))


func _normalize_dialogue(dialogue_data: Variant) -> Dictionary:
	if dialogue_data is Dictionary:
		var definition := Dictionary(dialogue_data).duplicate(true)
		if definition.has("nodes"):
			return definition
		return _lines_to_dialogue(Array(definition.get("lines", [])))
	if dialogue_data is Array:
		return _lines_to_dialogue(Array(dialogue_data))
	return {}


func _lines_to_dialogue(source_lines: Array) -> Dictionary:
	if source_lines.is_empty():
		return {}
	var generated_nodes := {}
	for index in range(source_lines.size()):
		var node: Dictionary = Dictionary(source_lines[index]).duplicate(true)
		node["next"] = (
			"line_%d" % (index + 1)
			if index + 1 < source_lines.size()
			else ""
		)
		generated_nodes["line_%d" % index] = node
	return {
		"start": "line_0",
		"nodes": generated_nodes,
	}


func _is_mobile_platform() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("ios")
		or OS.has_feature("android")
	)
