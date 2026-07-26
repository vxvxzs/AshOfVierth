extends Control

@onready var new_game_button: Button = %NewGame
@onready var settings_button: Button = %Settings
@onready var credits_button: Button = %Credits
@onready var quit_button: Button = %Quit
@onready var status_label: Label = %Status
@onready var modal_dim: ColorRect = %ModalDim
@onready var modal_center: CenterContainer = %ModalCenter
@onready var modal_title: Label = %ModalTitle
@onready var modal_body: Label = %ModalBody
@onready var volume_row: HBoxContainer = %VolumeRow
@onready var master_volume: HSlider = %MasterVolume
@onready var modal_back: Button = %ModalBack

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_show_settings)
	credits_button.pressed.connect(_show_credits)
	quit_button.pressed.connect(get_tree().quit)
	modal_back.pressed.connect(_close_modal)
	master_volume.value_changed.connect(_on_master_volume_changed)
	for button: Button in [
		new_game_button,
		settings_button,
		credits_button,
		quit_button,
	]:
		button.mouse_entered.connect(button.grab_focus)
	modulate.a = 0.0
	var entrance := create_tween()
	entrance.set_trans(Tween.TRANS_QUAD)
	entrance.set_ease(Tween.EASE_OUT)
	entrance.tween_property(self, "modulate:a", 1.0, 0.55)
	new_game_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not modal_center.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()

func _on_new_game_pressed() -> void:
	SceneDirector.start_new_game()

func _show_settings() -> void:
	_open_modal(
		"USTAWIENIA",
		"Dopasuj głośność wszystkich dźwięków gry.",
		true
	)

func _show_credits() -> void:
	_open_modal(
		"TWÓRCY",
		"Ash of Vierth: First Fracture\n"
		+ "Projekt i reżyseria: vxvxzs\n"
		+ "Silnik: Godot 4",
		false
	)

func _open_modal(title: String, body: String, show_volume: bool) -> void:
	modal_title.text = title
	modal_body.text = body
	volume_row.visible = show_volume
	modal_dim.show()
	modal_center.show()
	modal_back.grab_focus()

func _close_modal() -> void:
	modal_dim.hide()
	modal_center.hide()
	settings_button.grab_focus()

func _on_master_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_volume_db(
		master_bus,
		linear_to_db(maxf(value / 100.0, 0.0001))
	)
