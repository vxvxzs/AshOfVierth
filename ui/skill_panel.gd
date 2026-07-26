extends CanvasLayer

@onready var status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var unlock_button: Button = $CenterContainer/PanelContainer/VBoxContainer/UnlockButton
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton

func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_pressed)
	close_button.pressed.connect(hide)
	ProgressionManager.ability_unlocked.connect(_on_ability_unlocked)
	hide()

func open_panel() -> void:
	_refresh()
	show()

func _on_unlock_pressed() -> void:
	if ProgressionManager.unlock_short_step():
		_refresh()
		hide()

func _on_ability_unlocked(ability_id: StringName) -> void:
	if ability_id == &"short_step":
		_refresh()

func _refresh() -> void:
	if ProgressionManager.is_ability_unlocked(&"short_step"):
		var instruction := "Tap STEP for a short evasive step." if _is_mobile_platform() else "Use Space for a short evasive step."
		status_label.text = "Short Step awakened.\n%s" % instruction
		unlock_button.text = "Awakened"
		unlock_button.disabled = true
	else:
		status_label.text = "Short Step\nA small evasive step.\nCost: %d Light\nCurrent: %d" % [ProgressionManager.SHORT_STEP_COST, ProgressionManager.light_points]
		unlock_button.text = "Awaken Short Step"
		unlock_button.disabled = ProgressionManager.light_points < ProgressionManager.SHORT_STEP_COST

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide()
