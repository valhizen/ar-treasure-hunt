extends Control

@onready var continue_button = $Container/Continue
@onready var new_game_button = $Container/NewGame
@onready var options_button = $Container/Options
@onready var quit_button = $Container/Quit

func _ready():
	# Check if save file exists to enable/disable continue button
	if SaveManager.has_save_file():
		continue_button.disabled = false
	else:
		continue_button.disabled = true
	
	# Connect button signals
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_continue_pressed():
	if SaveManager.load_game():
		SaveManager.start_autosave()
		var last_map = SaveManager.get_current_map()
		print("Attempting to load map: " + last_map)
		
		if last_map != "":
			var map_path = "res://Sceans/Maps/" + last_map + ".tscn"
			print("Full path: " + map_path)
			
			if ResourceLoader.exists(map_path):
				get_tree().change_scene_to_file(map_path)
			else:
				print("Map file not found: " + map_path)
				# Fallback to bhaktapur instead of kathmandu
				get_tree().change_scene_to_file("res://Sceans/Maps/bhaktapur.tscn")
		else:
			# Default to bhaktapur if no map is set
			print("No last map found, loading bhaktapur")
			get_tree().change_scene_to_file("res://Sceans/Maps/bhaktapur.tscn")
	else:
		print("Failed to load save file")

func _on_new_game_pressed():
	# Show confirmation dialog if save exists
	if SaveManager.has_save_file():
		show_new_game_confirmation()
	else:
		start_new_game()

func show_new_game_confirmation():
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Starting a new game will overwrite your existing save. Continue?"
	dialog.ok_button_text = "Yes"
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): 
		start_new_game()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()

func start_new_game():
	SaveManager.create_new_save()
	SaveManager.start_autosave()
	# Start at the first map
	get_tree().change_scene_to_file("res://Sceans/Maps/bhaktapur.tscn")

func _on_options_pressed():
	get_tree().change_scene_to_file("res://Sceans/MainMenu/options_scean.tscn")

func _on_quit_pressed():
	get_tree().quit()
