extends Control
## MainMenu - Game entry point with robust error handling
## Flow: Main Menu → House (wake up) → Prologue Map (Bhaktapur)

#region Scene References
@export_file("*.tscn") var options_scene_path: String = "res://Scenes/Core/UI/options_scean.tscn"
## First scene - Player wakes up inside the house
@export_file("*.tscn") var wake_up_scene_path: String = "res://Scenes/MainCharacter/main_character_house.tscn"
#endregion

#region Node References
@onready var container: Control = $Container
@onready var continue_button: Control = $PanelContainer/VBoxContainer/Continue
@onready var new_game_button: Control = $PanelContainer/VBoxContainer/NewGame
@onready var options_button: Control = $PanelContainer/VBoxContainer/Options
@onready var quit_button: Control = $PanelContainer/VBoxContainer/Quit
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
#endregion

var _is_transitioning: bool = false


func _ready() -> void:
	get_tree().paused = false
	_is_transitioning = false
	
	print("[MainMenu] ========== MAIN MENU READY ==========")
	print("[MainMenu] Wake up scene path: %s" % wake_up_scene_path)
	print("[MainMenu] Scene exists: %s" % ResourceLoader.exists(wake_up_scene_path))
	
	# Debug: Check autoloads
	_debug_check_autoloads()
	
	# Connect buttons
	_setup_buttons()
	
	print("[MainMenu] =====================================")


func _debug_check_autoloads() -> void:
	"""Check if required autoloads exist"""
	var save_manager = get_node_or_null("/root/SaveManager")
	var game_manager = get_node_or_null("/root/GameManager")
	var player_data = get_node_or_null("/root/PlayerData")
	
	print("[MainMenu] SaveManager exists: %s" % (save_manager != null))
	print("[MainMenu] GameManager exists: %s" % (game_manager != null))
	print("[MainMenu] PlayerData exists: %s" % (player_data != null))


func _setup_buttons() -> void:
	"""Setup all button connections"""
	# Continue Button
	if continue_button:
		_connect_button(continue_button, _on_continue_pressed)
		_update_continue_availability()
		print("[MainMenu] Continue button connected")
	else:
		push_warning("[MainMenu] Continue button not found at $Container/Continue")
	
	# New Game Button
	if new_game_button:
		_connect_button(new_game_button, _on_new_game_pressed)
		print("[MainMenu] NewGame button connected")
	else:
		push_error("[MainMenu] NewGame button not found at $Container/NewGame")
	
	# Options Button
	if options_button:
		_connect_button(options_button, _on_options_pressed)
		print("[MainMenu] Options button connected")
	else:
		push_warning("[MainMenu] Options button not found at $Container/Options")
	
	# Quit Button
	if quit_button:
		_connect_button(quit_button, _on_quit_pressed)
		print("[MainMenu] Quit button connected")
	else:
		push_warning("[MainMenu] Quit button not found at $Container/Quit")


func _connect_button(button: Control, callback: Callable) -> void:
	"""Connect button input - works with Button or TextureRect-based buttons"""
	if button is BaseButton:
		# Standard Button, TextureButton, etc.
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		print("[MainMenu] Connected %s via pressed signal" % button.name)
	else:
		# Custom Control-based buttons (TextureRect, etc.)
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					print("[MainMenu] Click detected on %s" % button.name)
					callback.call()
		)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		print("[MainMenu] Connected %s via gui_input" % button.name)


func _update_continue_availability() -> void:
	"""Disable continue if no saves exist"""
	if not continue_button:
		return
	
	var has_save = false
	var save_manager = get_node_or_null("/root/SaveManager")
	
	if save_manager and save_manager.has_method("get_all_saves"):
		var saves = save_manager.get_all_saves()
		for save in saves:
			if save.get("exists", false):
				has_save = true
				break
		print("[MainMenu] Found existing save: %s" % has_save)
	else:
		print("[MainMenu] SaveManager not available, disabling continue")
	
	# Update button appearance
	if not has_save:
		continue_button.modulate.a = 0.5
		if continue_button is BaseButton:
			continue_button.disabled = true
		else:
			continue_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		continue_button.modulate.a = 1.0
		if continue_button is BaseButton:
			continue_button.disabled = false
		else:
			continue_button.mouse_filter = Control.MOUSE_FILTER_STOP


#region Button Handlers
func _on_continue_pressed() -> void:
	"""Continue from last save"""
	if _is_transitioning:
		return
	
	print("[MainMenu] >>> CONTINUE PRESSED <<<")
	_is_transitioning = true
	
	_play_button_audio(continue_button)
	await _wait_for_button_animation(continue_button)
	
	var save_manager = get_node_or_null("/root/SaveManager")
	var game_manager = get_node_or_null("/root/GameManager")
	
	if game_manager and game_manager.has_method("continue_game"):
		game_manager.continue_game()
	elif save_manager and save_manager.has_method("load_game"):
		var save_data = save_manager.load_game()
		if save_data:
			var map_name = save_data.get("current_map", "")
			if map_name != "":
				var scene_path = "res://Scenes/Core/Maps/%s.tscn" % map_name
				print("[MainMenu] Loading saved map: %s" % scene_path)
				_change_scene(scene_path)
			else:
				print("[MainMenu] No map in save, going to wake up scene")
				_change_scene(wake_up_scene_path)
		else:
			print("[MainMenu] No save data found, going to wake up scene")
			_change_scene(wake_up_scene_path)
	else:
		print("[MainMenu] No save system, going to wake up scene")
		_change_scene(wake_up_scene_path)


func _on_new_game_pressed() -> void:
	"""Start new game"""
	if _is_transitioning:
		return
	
	print("[MainMenu] >>> NEW GAME PRESSED <<<")
	_is_transitioning = true
	
	_play_button_audio(new_game_button)
	await _wait_for_button_animation(new_game_button)
	
	# Reset player data if available
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.has_method("reset_all"):
		player_data.reset_all()
		print("[MainMenu] Player data reset")
	
	# Check if GameManager handles new game
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("start_new_game"):
		print("[MainMenu] Using GameManager.start_new_game()")
		game_manager.start_new_game()
	else:
		# Direct scene change
		print("[MainMenu] Direct scene change to: %s" % wake_up_scene_path)
		_change_scene(wake_up_scene_path)


func _on_options_pressed() -> void:
	"""Open options menu"""
	if _is_transitioning:
		return
	
	print("[MainMenu] >>> OPTIONS PRESSED <<<")
	_is_transitioning = true
	
	_play_button_audio(options_button)
	await _wait_for_button_animation(options_button)
	
	_change_scene(options_scene_path)


func _on_quit_pressed() -> void:
	"""Quit game"""
	if _is_transitioning:
		return
	
	print("[MainMenu] >>> QUIT PRESSED <<<")
	_is_transitioning = true
	
	_play_button_audio(quit_button)
	await _wait_for_button_animation(quit_button)
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("quit_game"):
		game_manager.quit_game()
	else:
		get_tree().quit()
#endregion


#region Scene Transition
func _change_scene(scene_path: String) -> void:
	"""Change scene with validation"""
	print("[MainMenu] Attempting to load: %s" % scene_path)
	
	# Verify scene exists
	if not ResourceLoader.exists(scene_path):
		push_error("[MainMenu] SCENE NOT FOUND: %s" % scene_path)
		_is_transitioning = false
		return
	
	# Optional: Add fade transition
	await _fade_out()
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[MainMenu] Failed to change scene! Error: %d" % error)
		_is_transitioning = false
	else:
		print("[MainMenu] Scene change initiated successfully")


func _fade_out(duration: float = 0.5) -> void:
	"""Fade to black before scene change"""
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	
	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, duration)
	await tween.finished
#endregion


#region Helpers
func _play_button_audio(button: Control) -> void:
	"""Play the button's AudioStreamPlayer if it exists"""
	if button and button.has_node("AudioStreamPlayer"):
		var audio = button.get_node("AudioStreamPlayer") as AudioStreamPlayer
		if audio:
			audio.play()
	elif audio_player:
		audio_player.play()


func _wait_for_button_animation(button: Control) -> void:
	"""Wait for button's click animation to finish"""
	if button and button.has_node("AnimationPlayer"):
		var anim_player: AnimationPlayer = button.get_node("AnimationPlayer")
		if anim_player.has_animation("click"):
			anim_player.play("click")
			await anim_player.animation_finished
			return
		elif anim_player.has_animation("pressed"):
			anim_player.play("pressed")
			await anim_player.animation_finished
			return
		elif anim_player.is_playing():
			await anim_player.animation_finished
			return
	
	# Default short delay
	await get_tree().create_timer(0.15).timeout
#endregion


#region Input Handling (Backup)
func _input(event: InputEvent) -> void:
	"""Backup input handling for keyboard navigation"""
	if _is_transitioning:
		return
	
	# Allow Enter/Space to activate focused button
	if event.is_action_pressed("ui_accept"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused.get_parent() == container:
			# Trigger the button
			if focused == new_game_button:
				_on_new_game_pressed()
			elif focused == continue_button and continue_button.modulate.a > 0.9:
				_on_continue_pressed()
			elif focused == options_button:
				_on_options_pressed()
			elif focused == quit_button:
				_on_quit_pressed()
#endregion
