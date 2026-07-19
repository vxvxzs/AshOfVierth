class_name MobileActionButton
extends Control

signal activated

@export var caption := "STRIKE"
@export var accent_color := Color("d89b65")

var active_pointer := -1
var pressed_visual := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1:
			active_pointer = event.index
			_activate()
		elif not event.pressed and event.index == active_pointer:
			_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_pointer = 0
			_activate()
		elif active_pointer == 0:
			_release()

func _activate() -> void:
	pressed_visual = true
	activated.emit()
	queue_redraw()

func _release() -> void:
	active_pointer = -1
	pressed_visual = false
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	var fill := Color(accent_color, 0.94 if pressed_visual else 0.68)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 28, Color("efffff"), 2.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, 6), caption, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 17, Color("ffffff"))
