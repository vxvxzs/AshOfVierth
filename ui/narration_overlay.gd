class_name NarrationOverlay
extends CanvasLayer

## Non-blocking narration for cutscenes and inner thoughts.
## It owns its layout so no prior scene/UI style can alter individual lines.

signal sequence_finished

const DEFAULT_LINE_DURATION := 4.8
const PANEL_WIDTH := 820.0
const PANEL_HEIGHT := 122.0
const TYPEWRITER_CHARACTERS_PER_SECOND := 42.0
const MINIMUM_READING_TIME := 1.35

var _panel: PanelContainer
var _speaker_label: Label
var _body_label: Label
var _lines: Array[Dictionary] = []
var _line_index := -1
var _time_left := 0.0
var _typed_character_count := 0.0
var _current_text_length := 0

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layout()
	_panel.hide()

func play_sequence(new_lines: Array) -> void:
	_lines.clear()
	for raw_line in new_lines:
		if raw_line is Dictionary:
			_lines.append(raw_line)
	_line_index = -1
	_next_line()

func stop() -> void:
	_line_index = -1
	_time_left = 0.0
	_typed_character_count = 0.0
	_current_text_length = 0
	_panel.hide()

func is_playing() -> bool:
	return _line_index >= 0

func _process(delta: float) -> void:
	if _line_index < 0:
		return
	if _typed_character_count < _current_text_length:
		_typed_character_count = minf(_typed_character_count + TYPEWRITER_CHARACTERS_PER_SECOND * delta, _current_text_length)
		_body_label.visible_characters = ceili(_typed_character_count)
	_time_left -= delta
	if _time_left <= 0.0:
		_next_line()

func _next_line() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		stop()
		sequence_finished.emit()
		return
	var line := _lines[_line_index]
	_speaker_label.text = str(line.get("speaker", "Iven"))
	var line_text := str(line.get("text", ""))
	_body_label.text = line_text
	_current_text_length = line_text.length()
	_typed_character_count = 0.0
	_body_label.visible_characters = 0
	var typewriter_duration := float(_current_text_length) / TYPEWRITER_CHARACTERS_PER_SECOND
	_time_left = maxf(float(line.get("duration", DEFAULT_LINE_DURATION)), typewriter_duration + MINIMUM_READING_TIME)
	_panel.show()

func _build_layout() -> void:
	var screen_root := Control.new()
	screen_root.name = "NarrationScreenRoot"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)

	_panel = PanelContainer.new()
	_panel.name = "NarrationPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.position = Vector2(-PANEL_WIDTH * 0.5, -PANEL_HEIGHT - 42.0)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	screen_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.custom_minimum_size = Vector2(0, 22)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color("9ef2ef"))
	layout.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.custom_minimum_size = Vector2(0, 52)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.add_theme_font_size_override("font_size", 20)
	_body_label.add_theme_color_override("font_color", Color("edf3ef"))
	layout.add_child(_body_label)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091016f5")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("58c4ca")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style
