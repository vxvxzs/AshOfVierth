class_name DayNightEnvironment
extends Node

@export var canvas_modulate_path: NodePath
@export var lights_root_path: NodePath
@export var auto_discover_group := true
@export var light_group: StringName = &"day_night_lights"
@export_range(0.0, 20.0, 0.1) var color_smoothing_speed := 4.0
@export_range(0.0, 20.0, 0.1) var light_fade_speed := 4.5
@export var warm_light_color := Color("ffc06a")
@export_range(0.0, 4.0, 0.05) var street_light_energy := 1.05
@export_range(0.1, 8.0, 0.1) var street_light_radius := 3.2
@export_range(0.0, 4.0, 0.05) var torch_light_energy := 1.2
@export_range(0.1, 8.0, 0.1) var torch_light_radius := 2.8
@export_range(0.0, 4.0, 0.05) var window_light_energy := 0.72
@export_range(0.1, 8.0, 0.1) var window_light_radius := 2.6

var _cycle: Node
var _canvas_modulate: CanvasModulate
var _managed_lights: Array[PointLight2D] = []
var _target_light_energy: Dictionary = {}
var _lights_should_be_enabled := false


func _ready() -> void:
	_cycle = get_node_or_null("/root/DayNightCycle")
	_canvas_modulate = get_node_or_null(
		canvas_modulate_path
	) as CanvasModulate
	refresh_lights()
	if _cycle == null:
		push_warning("DayNightEnvironment requires DayNightCycle autoload.")
		set_process(false)
		return
	_cycle.lighting_state_changed.connect(_on_lighting_state_changed)
	_apply_cycle_state(true)


func _process(delta: float) -> void:
	if _cycle == null:
		return
	if _canvas_modulate != null:
		var target_color: Color = _cycle.get_ambient_color()
		if color_smoothing_speed <= 0.0:
			_canvas_modulate.color = target_color
		else:
			var color_weight := (
				1.0 - exp(-color_smoothing_speed * delta)
			)
			_canvas_modulate.color = _canvas_modulate.color.lerp(
				target_color,
				color_weight
			)
	_update_light_fades(delta)


func refresh_lights() -> void:
	_managed_lights.clear()
	_target_light_energy.clear()
	var lights_root := get_node_or_null(lights_root_path)
	if lights_root != null:
		_collect_point_lights(lights_root)
	if auto_discover_group and is_inside_tree():
		for candidate in get_tree().get_nodes_in_group(light_group):
			var point_light := candidate as PointLight2D
			if (
				point_light != null
				and not _managed_lights.has(point_light)
			):
				_managed_lights.append(point_light)
	for light in _managed_lights:
		_configure_light_profile(light)
	if _cycle != null:
		_apply_lighting_state(
			_cycle.should_world_lights_be_enabled(),
			true
		)


func get_managed_light_count() -> int:
	return _managed_lights.size()


func apply_now() -> void:
	_apply_cycle_state(true)


func _apply_cycle_state(immediate_color: bool) -> void:
	if _cycle == null:
		return
	if _canvas_modulate != null and immediate_color:
		_canvas_modulate.color = _cycle.get_ambient_color()
	_apply_lighting_state(
		_cycle.should_world_lights_be_enabled(),
		true
	)


func _on_lighting_state_changed(lights_enabled: bool) -> void:
	_apply_lighting_state(lights_enabled, false)


func _apply_lighting_state(
	lights_enabled: bool,
	immediate: bool
) -> void:
	_lights_should_be_enabled = lights_enabled
	for light in _managed_lights:
		if not is_instance_valid(light):
			continue
		var target_energy := _get_target_energy(light)
		if lights_enabled:
			light.enabled = true
		if immediate:
			light.energy = target_energy if lights_enabled else 0.0
			light.enabled = lights_enabled


func _update_light_fades(delta: float) -> void:
	var weight := 1.0
	if light_fade_speed > 0.0:
		weight = 1.0 - exp(-light_fade_speed * delta)
	for light in _managed_lights:
		if not is_instance_valid(light):
			continue
		var target_energy := (
			_get_target_energy(light)
			if _lights_should_be_enabled
			else 0.0
		)
		if _lights_should_be_enabled:
			light.enabled = true
			light.energy = lerpf(light.energy, target_energy, weight)
		else:
			light.energy = lerpf(light.energy, 0.0, weight)
			if light.energy <= 0.01:
				light.energy = 0.0
				light.enabled = false


func _configure_light_profile(light: PointLight2D) -> void:
	var owner_name := ""
	if light.get_parent() != null:
		owner_name = String(light.get_parent().name).to_lower()
	light.color = warm_light_color
	if owner_name.contains("torch"):
		_target_light_energy[light.get_instance_id()] = torch_light_energy
		light.texture_scale = torch_light_radius
	elif owner_name.contains("streetlamp") or owner_name.contains("lamp"):
		_target_light_energy[light.get_instance_id()] = street_light_energy
		light.texture_scale = street_light_radius
	else:
		_target_light_energy[light.get_instance_id()] = window_light_energy
		light.texture_scale = window_light_radius


func _get_target_energy(light: PointLight2D) -> float:
	return float(
		_target_light_energy.get(
			light.get_instance_id(),
			window_light_energy
		)
	)


func _collect_point_lights(root_node: Node) -> void:
	var root_light := root_node as PointLight2D
	if root_light != null:
		_managed_lights.append(root_light)
	for child in root_node.get_children():
		_collect_point_lights(child)
