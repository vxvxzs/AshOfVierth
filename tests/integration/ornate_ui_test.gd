extends SceneTree

const MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const DIALOGUE_PATH := "res://scenes/dialogue/DialogueUI.tscn"
const NOTIFIER_PATH := "res://scenes/ui/QuestNotifier.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu_scene := load(MENU_PATH) as PackedScene
	var dialogue_scene := load(DIALOGUE_PATH) as PackedScene
	var notifier_scene := load(NOTIFIER_PATH) as PackedScene
	assert(menu_scene != null, "Ornate main menu must load.")
	assert(dialogue_scene != null, "Ornate dialogue UI must load.")
	assert(notifier_scene != null, "Ornate objective notification must load.")

	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu.get_node("%NewGame").text == "GRAJ")
	assert(menu.get_node("%Settings").text == "USTAWIENIA")
	assert(
		menu.get_node(
			"CenterContainer/MenuFrame/MarginContainer/VBoxContainer/Title"
		).get_theme_font("font") is FontFile,
		"The title must use the bundled dark-fantasy display font."
	)
	assert(
		menu.get_node("%NewGame").get_theme_stylebox("normal") is StyleBoxTexture,
		"Main menu buttons must use reusable textured brass frames."
	)
	menu.get_node("%Settings").pressed.emit()
	assert(
		menu.get_node("%ModalCenter").visible
		and menu.get_node("%VolumeRow").visible,
		"Settings must open a functional ornate volume panel."
	)
	menu.get_node("%ModalBack").pressed.emit()
	menu.get_node("%Credits").pressed.emit()
	assert(
		menu.get_node("%ModalCenter").visible
		and not menu.get_node("%VolumeRow").visible,
		"Credits must open in the reusable ornate modal."
	)
	menu.queue_free()
	await process_frame

	var dialogue := dialogue_scene.instantiate() as DialoguePanel
	root.add_child(dialogue)
	await process_frame
	var panel := dialogue.get_node("MarginContainer/PanelContainer") as PanelContainer
	var portrait_frame := dialogue.get_node(
		"MarginContainer/PanelContainer/DialogueRow/PortraitFrame"
	) as PanelContainer
	var choice_template := dialogue.get_node(
		"MarginContainer/PanelContainer/DialogueRow/Content/Choices/ChoiceStyleTemplate"
	) as Button
	assert(
		panel.get_theme_stylebox("panel") is StyleBoxTexture,
		"Dialogue window must use the ornate nine-slice frame."
	)
	assert(
		portrait_frame.get_theme_stylebox("panel") is StyleBoxTexture,
		"Dialogue portraits must use the matching ornate frame."
	)
	assert(
		choice_template.get_theme_stylebox("normal") is StyleBoxTexture,
		"Dialogue choices must reuse the ornate button frame."
	)

	dialogue.open_dialogue({
		"start": "choice",
		"nodes": {
			"choice": {
				"speaker": "Iven",
				"text": "Test",
				"choices": [
					{"id": "one", "text": "First", "next": ""},
					{"id": "two", "text": "Second", "next": ""},
				],
			},
		},
	})
	assert(dialogue.get_choice_count() == 2)
	dialogue.close_dialogue()
	assert(not paused, "Closing dialogue must restore the prior pause state.")

	dialogue.open_dialogue({
		"start": "first",
		"nodes": {
			"first": {
				"speaker": "Iven",
				"text": "First",
				"next": "second",
			},
			"second": {
				"speaker": "Iven",
				"text": "Second",
				"next": "",
			},
		},
	})
	assert(paused, "Dialogue must own the tree pause while open.")
	dialogue.open_dialogue({
		"start": "replacement",
		"nodes": {
			"replacement": {
				"speaker": "Wrong",
				"text": "Must be ignored",
				"next": "",
			},
		},
	})
	assert(
		dialogue.get_current_node_id() == "first",
		"Opening over an active dialogue must not overwrite pause ownership."
	)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(640, 500)
	dialogue._input(touch)
	assert(
		dialogue.get_current_node_id() == "second",
		"A screen touch must advance a choice-free dialogue."
	)
	dialogue.close_dialogue()
	assert(not paused, "Touch-driven dialogue must release the tree pause.")

	var disposable_dialogue := dialogue_scene.instantiate() as DialoguePanel
	root.add_child(disposable_dialogue)
	disposable_dialogue.open_dialogue([
		{"speaker": "Iven", "text": "Temporary"},
	])
	assert(paused, "Temporary dialogue must pause the tree.")
	root.remove_child(disposable_dialogue)
	disposable_dialogue.free()
	assert(
		not paused,
		"Dialogue removal must restore pause state even without an explicit close."
	)

	var scene_director := root.get_node("/root/SceneDirector")
	scene_director.change_scene(
		"res://assets/ui/ornate/button_frame.png"
	)
	assert(
		not scene_director.is_transitioning
		and scene_director.fade.color.a == 0.0,
		"SceneDirector must reject non-scene resources without trapping the fade."
	)

	var notifier := notifier_scene.instantiate()
	root.add_child(notifier)
	await process_frame
	assert(
		notifier.get_node(
			"Root/CenterContainer/PanelContainer"
		).get_theme_stylebox("panel") is StyleBoxTexture,
		"Objective notifications must share the ornate frame."
	)

	print("ORNATE_UI_TEST: PASS")
	quit(0)
