extends Control

@onready var load_button = $Container/Load
@onready var save_button = $Container/Save
# Add a back button - adjust the path based on where you place it
# Option 1: If back button is inside Container
# @onready var back_button = $Container/Back
# Option 2: If back button is separate (recommended)
@onready var back_button = $BackButton

# Optional: Add a label to show save info
@onready var save_info_label = $SaveInfoLabel  # Add this if you have one

func _ready():
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	update_save_info()
	
	# Disable save button if no active game
	if not SaveManager.is_game_loaded:
		save_button.disabled = true

func update_save_info():
	# Only update if you have a save info label
	if save_info_label == null:
		return
		
	if SaveManager.has_save_file() and SaveManager.current_save != null:
		var info_text = "Last Save: %s\nPlay Time: %s" % [
			SaveManager.current_save.save_timestamp,
			SaveManager.get_play_time_formatted()
		]
		save_info_label.text = info_text
	else:
		save_info_label.text = "No save file found"

func _on_load_pressed():
	if SaveManager.has_save_file():
		if SaveManager.load_game():
			SaveManager.start_autosave()
			var last_map = SaveManager.get_current_map()
			get_tree().change_scene_to_file("res://Sceans/" + last_map + ".tscn")
		else:
			show_error_dialog("Failed to load save file")
	else:
		show_error_dialog("No save file found")

func _on_save_pressed():
	if SaveManager.is_game_loaded:
		if SaveManager.save_game():
			update_save_info()
			show_info_dialog("Game saved successfully!")
		else:
			show_error_dialog("Failed to save game")
	else:
		show_error_dialog("No active game to save")

func _on_back_pressed():
	# Return to main menu or previous scene
	if SaveManager.is_game_loaded:
		# Return to the current map the player was on
		var current_map = SaveManager.get_current_map()
		get_tree().change_scene_to_file("res://Sceans/" + current_map + ".tscn")
	else:
		# Return to main menu
		get_tree().change_scene_to_file("res://Sceans/MainMenu/main_menu.tscn")

func show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func show_info_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
