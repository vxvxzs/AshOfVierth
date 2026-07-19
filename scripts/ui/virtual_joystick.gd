class_name VirtualJoystick
extends Control

signal input_changed(direction: Vector2)

const BASE_COLOR := Color(0.07, 0.16, 0.22, 0.64)
const BASE_BORDER_COLOR := Color(0.45, 0.83, 0.86, 0.72)
const KNOB_COLOR := Color(0.52, 0.9, 0.92, 0.82)
const MAX_RADIUS := 54.0

var active_pointer := -1
var current_direction := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1:
			active_pointer = event.index
			_update_direction(event.position)
		elif not event.pressed and event.index == active_pointer:
			_release()
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_update_direction(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_pointer = 0
			_update_direction(event.position)
		elif active_pointer == 0:
			_release()
	elif event is InputEventMouseMotion and active_pointer == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_direction(event.position)

func _update_direction(pointer_position: Vector2) -> void:
	var offset := pointer_position - size * 0.5
	var clamped_offset := offset.limit_length(MAX_RADIUS)
	current_direction = clamped_offset / MAX_RADIUS
	input_changed.emit(current_direction)
	queue_redraw()

func _release() -> void:
	active_pointer = -1
	current_direction = Vector2.ZERO
	input_changed.emit(current_direction)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, MAX_RADIUS + 15.0, BASE_COLOR)
	draw_arc(center, MAX_RADIUS + 15.0, 0.0, TAU, 32, BASE_BORDER_COLOR, 2.0, true)
	draw_circle(center + current_direction * MAX_RADIUS, 25.0, KNOB_COLOR)
	draw_arc(center + current_direction * MAX_RADIUS, 25.0, 0.0, TAU, 24, Color("d9ffff"), 2.0, true)
