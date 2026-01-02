extends Control
## PauseMenu - In-game pause menu
## Attach to PauseMenu node, add as child to map's CanvasLayer

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Sceans/MainMenu/main_menu.tscn"
@export_file("*.tscn") var options_scene_path: String = "res://Sceans/MainMenu/OptionsScean.tscn"
#endregion

#region Configuration
## Show save slots directly in pause menu
@export var show_save_slots: bool = false
#endregion

#region Node References
var panel: Panel
var resume_button: Button
var save_button: Button
var options_button: Button
var main_menu_button: Button
var quit_button: Button
var title_label: Label

# Save slots (if show_save_slots is true)
var save_slots_panel: Panel
#endregion

func _ready() -> void:
	# Process even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Start hidden
	hide()
	
	# Setup UI
	_setup_ui()
	
	# Connect to GameManager if available
	if GameManager:
		GameManager.game_paused.connect(show)
		GameManager.game_resumed.connect(hide)
	
	print("[PauseMenu] Ready")


func _setup_ui() -> void:
	"""Create pause menu UI"""
	# Background overlay
	var overlay = get_node_or_null("Overlay")
	if not overlay:
		overlay = ColorRect.new()
		overlay.name = "Overlay"
		overlay.color = Color(0, 0, 0, 0.5)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(overlay)
	
	# Main panel
	panel = get_node_or_null("Panel")
	if not panel:
		panel = Panel.new()
		panel.name = "Panel"
		panel.custom_minimum_size = Vector2(300, 400)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.size = Vector2(300, 400)
		panel.position = -panel.size / 2
		add_child(panel)
	
	# Container for buttons
	var container = panel.get_node_or_null("Container")
	if not container:
		container = VBoxContainer.new()
		container.name = "Container"
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.add_theme_constant_override("separation", 15)
		panel.add_child(container)
		
		# Add margin
		container.offset_left = 20
		container.offset_right = -20
		container.offset_top = 20
		container.offset_bottom = -20
	
	# Title
	title_label = container.get_node_or_null("Title")
	if not title_label:
		title_label = Label.new()
		title_label.name = "Title"
		title_label.text = "PAUSED"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 28)
		container.add_child(title_label)
		
		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		container.add_child(spacer)
	
	# Buttons
	resume_button = _get_or_create_button(container, "Resume", "Resume")
	save_button = _get_or_create_button(container, "Save", "Save Game")
	options_button = _get_or_create_button(container, "Options", "Options")
	main_menu_button = _get_or_create_button(container, "MainMenu", "Main Menu")
	quit_button = _get_or_create_button(container, "Quit", "Quit Game")
	
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _get_or_create_button(parent: Node, node_name: String, text: String) -> Button:
	"""Get existing button or create new one"""
	var button = parent.get_node_or_null(node_name)
	if not button:
		button = Button.new()
		button.name = node_name
		button.text = text
		button.custom_minimum_size = Vector2(0, 45)
		parent.add_child(button)
	return button


#region Show/Hide
func show_pause_menu() -> void:
	"""Show menu and pause game"""
	if GameManager:
		GameManager.pause_game()
	else:
		get_tree().paused = true
	
	show()
	
	# Focus first button
	if resume_button:
		resume_button.grab_focus()


func hide_pause_menu() -> void:
	"""Hide menu and resume game"""
	hide()
	
	if GameManager:
		GameManager.resume_game()
	else:
		get_tree().paused = false
#endregion

#region Button Handlers
func _on_resume_pressed() -> void:
	"""Resume game"""
	print("[PauseMenu] Resume")
	hide_pause_menu()


func _on_save_pressed() -> void:
	"""Save game"""
	print("[PauseMenu] Save")
	
	if show_save_slots:
		_show_save_slots()
	else:
		# Quick save to slot 1
		if SaveManager:
			var success = SaveManager.save_game(1, "Quick Save")
			_show_message("Game Saved!" if success else "Save Failed!")


func _on_options_pressed() -> void:
	"""Open options - go to options scene"""
	print("[PauseMenu] Options")
	
	# Store that we came from pause
	if SaveManager:
		SaveManager.set_meta("from_pause", true)
		SaveManager.set_meta("pause_scene", get_tree().current_scene.scene_file_path)
	
	get_tree().paused = false
	get_tree().change_scene_to_file(options_scene_path)


func _on_main_menu_pressed() -> void:
	"""Return to main menu"""
	print("[PauseMenu] Main Menu")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	if GameManager:
		GameManager.return_to_main_menu()
	else:
		get_tree().change_scene_to_file(main_menu_path)


func _on_quit_pressed() -> void:
	"""Quit game"""
	print("[PauseMenu] Quit")
	
	if GameManager:
		GameManager.quit_game()
	else:
		get_tree().quit()
#endregion

#region Save Slots (Optional)
func _show_save_slots() -> void:
	"""Show save slot selection"""
	# Hide main buttons
	panel.hide()
	
	# Create save slots panel if needed
	if not save_slots_panel:
		save_slots_panel = Panel.new()
		save_slots_panel.custom_minimum_size = Vector2(350, 450)
		save_slots_panel.set_anchors_preset(Control.PRESET_CENTER)
		save_slots_panel.size = Vector2(350, 450)
		save_slots_panel.position = -save_slots_panel.size / 2
		add_child(save_slots_panel)
		
		var container = VBoxContainer.new()
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.offset_left = 15
		container.offset_right = -15
		container.offset_top = 15
		container.offset_bottom = -15
		save_slots_panel.add_child(container)
		
		var title = Label.new()
		title.text = "SELECT SAVE SLOT"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(title)
		
		# Create slot buttons
		for i in range(1, 5):  # Slots 1-4
			var slot_btn = Button.new()
			slot_btn.name = "Slot%d" % i
			slot_btn.custom_minimum_size = Vector2(0, 60)
			slot_btn.pressed.connect(_on_save_slot_selected.bind(i))
			container.add_child(slot_btn)
		
		# Back button
		var back_btn = Button.new()
		back_btn.text = "Cancel"
		back_btn.custom_minimum_size = Vector2(0, 40)
		back_btn.pressed.connect(_hide_save_slots)
		container.add_child(back_btn)
	
	# Update slot info
	_update_save_slot_buttons()
	save_slots_panel.show()


func _hide_save_slots() -> void:
	"""Hide save slots, show main menu"""
	if save_slots_panel:
		save_slots_panel.hide()
	panel.show()


func _update_save_slot_buttons() -> void:
	"""Update slot button text"""
	if not save_slots_panel or not SaveManager:
		return
	
	var container = save_slots_panel.get_child(0)
	var saves = SaveManager.get_all_saves()
	
	for i in range(1, 5):
		var btn = container.get_node_or_null("Slot%d" % i)
		if btn and i < saves.size():
			var info = saves[i]
			if info.exists:
				btn.text = "Slot %d: %s\n%s" % [i, info.current_map, info.relative_time]
			else:
				btn.text = "Slot %d: [Empty]" % i


func _on_save_slot_selected(slot: int) -> void:
	"""Save to selected slot"""
	if SaveManager:
		var s    // If you prefer a smooth fade, use: float mix_threshold = progress;
uccess = SaveManager.save_game(slot, "Slot %d" % slot)
		_show_message("Saved to Slot %d!" % slot if success else "Save Failed!")
	
	_hide_save_slots()
#endregion

#region Input
func _input(event: InputEvent) -> void:
	# ESC toggles pause
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if save_slots_panel and save_slots_panel.visible:
				_hide_save_slots()
			else:
				_on_resume_pressed()
		else:
			# Only pause if playing (not in minigame)
			if GameManager and GameManager.is_playing():
				show_pause_menu()
			elif not GameManager:
				show_pause_menu()
		
		get_viewport().set_input_as_handled()
#endregion

#region Helpers
func _show_message(text: String) -> void:
	"""Show temporary message"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 50
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free)
#endregion
