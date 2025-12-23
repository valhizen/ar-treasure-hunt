extends Control
## MainMenu - Works with your existing animated buttons
## Attach to the root MainMenu node

#region Scene References
@export_file("*.tscn") var options_scene_path: String = "res://Sceans/MainMenu/OptionsScean.tscn"
@export_file("*.tscn") var first_map_path: String = "res://Sceans/Maps/bhaktapur.tscn"
#endregion

#region Node References
@onready var continue_button: Button = $Container/Continue
@onready var new_game_button: Button = $Container/NewGame
@onready var options_button: Button = $Container/Options
@onready var quit_button: Button = $Container/Quit
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
#endregion

func _ready() -> void:
	# Make sure game is unpaused
	get_tree().paused = false
	
	# Connect button signals
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		_update_continue_availability()
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	print("[MainMenu] Ready")


func _update_continue_availability() -> void:
	"""Disable continue if no saves exist"""
	if not continue_button:
		return
	
	var has_save = false
	
	if SaveManager:
		var saves = SaveManager.get_all_saves()
		for save in saves:
			if save.exists:
				has_save = true
				break
	
	continue_button.disabled = not has_save
	
	# Dim if disabled
	if not has_save:
		continue_button.modulate.a = 0.5
	else:
		continue_button.modulate.a = 1.0


#region Button Handlers
func _on_continue_pressed() -> void:
	"""Continue from last save"""
	print("[MainMenu] Continue pressed")
	
	# Wait for button animation if it has one
	await _wait_for_button_animation(continue_button)
	
	if GameManager:
		GameManager.continue_game()
	else:
		# Fallback
		var save_data = SaveManager.load_game() if SaveManager else null
		if save_data:
			get_tree().change_scene_to_file("res://Sceans/Maps/%s.tscn" % save_data.current_map)
		else:
			get_tree().change_scene_to_file(first_map_path)


func _on_new_game_pressed() -> void:
	"""Start new game"""
	print("[MainMenu] New Game pressed")
	
	await _wait_for_button_animation(new_game_button)
	
	if GameManager:
		GameManager.start_new_game()
	else:
		# Fallback
		if PlayerData:
			PlayerData.reset_all()
		get_tree().change_scene_to_file(first_map_path)


func _on_options_pressed() -> void:
	"""Open options menu"""
	print("[MainMenu] Options pressed")
	
	await _wait_for_button_animation(options_button)
	
	# Change to options scene
	get_tree().change_scene_to_file(options_scene_path)


func _on_quit_pressed() -> void:
	"""Quit game"""
	print("[MainMenu] Quit pressed")
	
	await _wait_for_button_animation(quit_button)
	
	if GameManager:
		GameManager.quit_game()
	else:
		get_tree().quit()
#endregion

#region Helpers
func _wait_for_button_animation(button: Button) -> void:
	"""Wait for button's click animation to finish"""
	if button and button.has_node("AnimationPlayer"):
		var anim_player = button.get_node("AnimationPlayer")
		if anim_player.is_playing():
			await anim_player.animation_finished
	else:
		# Small delay for feedback
		await get_tree().create_timer(0.1).timeout
#endregion
