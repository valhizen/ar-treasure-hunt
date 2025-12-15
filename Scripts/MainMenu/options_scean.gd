# options_scean.gd
extends Control

@onready var load_button = $Container/Load
@onready var back_button = $Container/BackButton

var save_slot_selector_scene = preload("res://Sceans/MainMenu/save_scean_selector.tscn")

func _ready():
	# Enable/disable load button based on save file existence
	var has_any_save = false
	for i in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		if SaveManager.has_save_in_slot(i):
			has_any_save = true
			break
	
	load_button.disabled = not has_any_save
	
	load_button.pressed.connect(_on_load_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_load_pressed():
	var selector = save_slot_selector_scene.instantiate()
	get_tree().root.add_child(selector)
	selector.setup("load", "Select Save to Load")
	selector.slot_selected.connect(_on_slot_selected)
	selector.cancelled.connect(func(): selector.queue_free())

func _on_slot_selected(slot: int):
	if SaveManager.load_game(slot):
		SaveManager.start_autosave()
		var last_map = SaveManager.get_current_map()
		var map_path = SaveManager.get_map_scene_path(last_map)
		get_tree().change_scene_to_file(map_path)
	else:
		print("Failed to load save")

func _on_back_pressed():
	if SaveManager.is_game_loaded:
		get_tree().paused = false
		queue_free()
	else:
		get_tree().change_scene_to_file("res://Sceans/MainMenu/main_menu.tscn")
