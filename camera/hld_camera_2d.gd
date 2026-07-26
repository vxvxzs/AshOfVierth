@tool
class_name HLDCamera2D
extends Camera2D

## Hybrid pixel-art camera:
## - smooth follow inside a small deadzone,
## - hard clamping to the active map/room bounds,
## - eased, detached pans when a CameraZone2D becomes active.

@export var target_path: NodePath
@export var world_rect := Rect2(0.0, 0.0, 960.0, 640.0)
@export var deadzone_size := Vector2(88.0, 56.0)
@export_range(1.0, 30.0, 0.1) var follow_speed := 9.0
@export_range(0.05, 2.0, 0.01) var transition_duration := 0.55
@export var pixel_snap_enabled := true

var _target: Node2D
var custom_target: Node2D
var _active_bounds := Rect2()
var _active_zone_id: StringName = &""
var _is_transitioning := false
var _transition_elapsed := 0.0
var _transition_length := 0.0
var _transition_start := Vector2.ZERO
var _transition_target := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"hybrid_camera")
	position_smoothing_enabled = false
	_target = get_node_or_null(target_path) as Node2D
	_active_bounds = world_rect
	if _target == null:
		push_warning("HLDCamera2D: target_path does not point to a Node2D.")
		return
	global_position = _pixel_snap(_clamp_to_bounds(_target.global_position))
	reset_smoothing()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_transitioning:
		_update_zone_transition(delta)
		return

	var tracked_target := _get_tracking_target()
	if tracked_target == null:
		return
	var desired := _deadzone_follow_position(tracked_target.global_position)
	desired = _clamp_to_bounds(desired)
	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = _pixel_snap(global_position.lerp(desired, follow_weight))


func enter_zone(
	zone_id: StringName,
	bounds: Rect2,
	focus_position: Vector2,
	duration_override: float = -1.0
) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	if zone_id == _active_zone_id and bounds == _active_bounds:
		return

	_active_zone_id = zone_id
	_active_bounds = bounds
	_transition_start = global_position
	# A fixed zone focus used to pull the camera towards the room centre even
	# when Iven entered near an edge. That was the visible "quarter-map" jump.
	# The active tracking target is authoritative; focus_position is only a
	# fallback for zones entered before a player target exists.
	var tracked_target := _get_tracking_target()
	var requested_focus := (
		tracked_target.global_position
		if tracked_target != null
		else focus_position
	)
	if requested_focus == Vector2.INF:
		requested_focus = bounds.get_center()
	_transition_target = _pixel_snap(_clamp_to_bounds(requested_focus))
	_transition_elapsed = 0.0
	_transition_length = (
		duration_override
		if duration_override > 0.0
		else transition_duration
	)
	_is_transitioning = true


func get_active_bounds() -> Rect2:
	return _active_bounds


func is_transitioning() -> bool:
	return _is_transitioning


func set_custom_target(new_target: Node2D) -> void:
	custom_target = new_target
	_is_transitioning = false


func clear_custom_target(snap_to_player: bool = true) -> void:
	custom_target = null
	_is_transitioning = false
	if not snap_to_player or _target == null:
		return
	# Dialogue close is deliberately immediate: no stale NPC focus and no
	# interpolation from a now-invalid target.
	global_position = _pixel_snap(_clamp_to_bounds(_target.global_position))
	reset_smoothing()


func get_custom_target() -> Node2D:
	return custom_target


func _update_zone_transition(delta: float) -> void:
	_transition_elapsed += delta
	var ratio := clampf(_transition_elapsed / _transition_length, 0.0, 1.0)
	var eased_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	global_position = _pixel_snap(
		_transition_start.lerp(_transition_target, eased_ratio)
	)
	if ratio >= 1.0:
		_is_transitioning = false


func _deadzone_follow_position(target_position: Vector2) -> Vector2:
	var desired := global_position
	var offset := target_position - global_position
	var half_deadzone := deadzone_size * 0.5

	if offset.x > half_deadzone.x:
		desired.x += offset.x - half_deadzone.x
	elif offset.x < -half_deadzone.x:
		desired.x += offset.x + half_deadzone.x
	if offset.y > half_deadzone.y:
		desired.y += offset.y - half_deadzone.y
	elif offset.y < -half_deadzone.y:
		desired.y += offset.y + half_deadzone.y
	return desired


func _clamp_to_bounds(desired: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), 0.001),
		maxf(absf(zoom.y), 0.001)
	)
	var half_view := viewport_size * 0.5 / safe_zoom
	desired.x = _clamp_axis(
		desired.x,
		_active_bounds.position.x,
		_active_bounds.size.x,
		half_view.x
	)
	desired.y = _clamp_axis(
		desired.y,
		_active_bounds.position.y,
		_active_bounds.size.y,
		half_view.y
	)
	return desired


func _clamp_axis(
	value: float,
	bounds_start: float,
	bounds_size: float,
	half_view_size: float
) -> float:
	if bounds_size <= half_view_size * 2.0:
		return bounds_start + bounds_size * 0.5
	return clampf(
		value,
		bounds_start + half_view_size,
		bounds_start + bounds_size - half_view_size
	)


func _get_tracking_target() -> Node2D:
	if is_instance_valid(custom_target):
		return custom_target
	custom_target = null
	return _target


func _pixel_snap(value: Vector2) -> Vector2:
	return value.round() if pixel_snap_enabled else value
