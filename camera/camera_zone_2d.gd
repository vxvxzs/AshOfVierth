@tool
class_name CameraZone2D
extends Area2D

## Editor-visible camera zone. The collision shape decides when it activates;
## camera_bounds decide how far the camera may travel after activation.

@export var zone_id: StringName = &"camera_zone"
@export var camera_bounds := Rect2(0.0, 0.0, 960.0, 640.0):
	set(value):
		camera_bounds = value
		queue_redraw()
@export var transition_focus := Vector2.INF:
	set(value):
		transition_focus = value
		queue_redraw()
@export_range(-1.0, 2.0, 0.01) var transition_duration_override := -1.0
@export var draw_bounds_in_game := false
@export var debug_color := Color(0.16, 0.88, 0.92, 0.22)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	monitoring = true
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	var camera := get_tree().get_first_node_in_group(&"hybrid_camera")
	if camera != null and camera.has_method("enter_zone"):
		camera.enter_zone(
			zone_id,
			camera_bounds,
			transition_focus,
			transition_duration_override
		)


func _draw() -> void:
	if not Engine.is_editor_hint() and not draw_bounds_in_game:
		return
	draw_rect(camera_bounds, Color(debug_color, 0.07), true)
	draw_rect(camera_bounds, debug_color, false, 2.0)
	if transition_focus != Vector2.INF:
		draw_circle(transition_focus, 7.0, Color(debug_color, 0.85))
