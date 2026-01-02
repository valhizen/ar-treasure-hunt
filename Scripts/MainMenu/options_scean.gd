extends Control
## OptionsScean - Options menu with Save/Load buttons
## Attach to root OptionsScean node

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Sceans/MainMenu/main_menu.tscn"
@export_file("*.tscn") var save_menu_path: String = "res://Sceans/MainMenu/SaveMenu.tscn"
#endregion

#region Node References
@onready var save_button: Button = $Container/Save
@onready var load_button: Button = $Container/Load
@onready var back_button: Button = $BackButton
@onready var save_info_label: Label = $SaveInfoLabel
#endregion

#region State
var came_from_pause: bool = false  # Track if we came from pause menu
var return_scene_path: String = ""
#endregion

func _ready() -> void:
	# Connect buttons
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Update UI
	_update_save_info()
	_update_button_states()
	
	print("[OptionsScean] Ready")


func _update_save_info() -> void:
	"""Show info about last save"""
	if not save_info_label:
		return
	
	if SaveManager:
		var saves = SaveManager.get_all_saves()
		var most_recent = null
		
		for save in saves:
			if save.exists:
				if most_recent == null or save.timestamp > most_recent.timestamp:
					most_recent = save
		
		if most_recent:
			save_info_label.text = "Last save: %s\n%s | %s" % [
				most_recent.current_map.capitalize(),
				most_recent.play_time,
				most_recent.relative_time
			]
		else:
			save_info_label.text = "No saves found"
	else:
		save_info_label.text = ""


func _update_button_states() -> void:
	"""Enable/disable buttons based on context"""
	# Save only available if playing (not from main menu)
	if save_button:
		var can_save = GameManager and GameManager.is_playing()
		save_button.disabled = not can_save
		save_button.modulate.a = 1.0 if can_save else 0.5
	
	# Load available if saves exist
	if load_button:
		var has_saves = false
		if SaveManager:
			for save in SaveManager.get_all_saves():
				if save.exists:
					has_saves = true
					break
		load_button.disabled = not has_saves
		load_button.modulate.a = 1.0 if has_saves else 0.5


#region Button Handlers
func _on_save_pressed() -> void:
	"""Open save menu"""
	print("[OptionsScean] Save pressed")
	
	await _wait_for_button_animation(save_button)
	
	# Go to save menu in "save mode"
	_go_to_save_menu(true)


func _on_load_pressed() -> void:
	"""Open load menu"""
	print("[OptionsScean] Load pressed")
	
	await _wait_for_button_animation(load_button)
	
	# Go to save menu in "load mode"
	_go_to_save_menu(false)


func _on_back_pressed() -> void:
	"""Go back to previous screen"""
	print("[OptionsScean] Back pressed")
	
	await _wait_for_button_animation(back_button)
	
	# Return to main menu
	get_tree().change_scene_to_file(main_menu_path)
#endregion

#region Navigation
func _go_to_save_menu(is_saving: bool) -> void:
	"""Navigate to save/load menu"""
	# Store mode for SaveMenu to use
	if SaveManager:
		SaveManager.set_meta("save_mode", is_saving)
	
	get_tree().change_scene_to_file(save_menu_path)
#endregion

#region Helpers
func _wait_for_button_animation(button: Button) -> void:
	"""Wait for button animation"""
	if button and button.has_node("AnimationPlayer"):
		var anim_player = button.get_node("AnimationPlayer")
		if anim_player.is_playing():
			await anim_player.animation_finished
	else:
		await get_tree().create_timer(0.1).timeout
#endregion

#region Input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
#endregion
