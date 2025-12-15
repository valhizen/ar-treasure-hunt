# MainMenu.gd
extends Control

@onready var continue_button = $Container/Continue
@onready var new_game_button = $Container/NewGame
@onready var load_button = $Container/Load
@onready var options_button = $Container/Options
@onready var quit_button = $Container/Quit

var save_slot_selector_scene = preload("res://Sceans/MainMenu/save_scean_selector.tscn")

func _ready():
	# Check if any save exists
	var has_any_save = false
	for i in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		if SaveManager.has_save_in_slot(i):
			has_any_save = true
			break
	
	continue_button.disabled = not has_any_save
	load_button.disabled = not has_any_save
	
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_continue_pressed():
	# Load most recent save
	var most_recent_slot = _get_most_recent_save_slot()
	if most_recent_slot > 0:
		_load_and_start_game(most_recent_slot)

func _get_most_recent_save_slot() -> int:
	var most_recent_slot = -1
	var most_recent_time = ""
	
	for i in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		if SaveManager.has_save_in_slot(i):
			var save_info = SaveManager.get_save_info(i)
			if save_info and (most_recent_time == "" or save_info["timestamp"] > most_recent_time):
				most_recent_time = save_info["timestamp"]
				most_recent_slot = i
	
	return most_recent_slot

func _on_new_game_pressed():
	_show_save_slot_selector("new_game", "Select Save Slot for New Game")

func _on_load_pressed():
	_show_save_slot_selector("load", "Select Save to Load")

func _show_save_slot_selector(mode: String, title: String):
	var selector = save_slot_selector_scene.instantiate()
	get_tree().root.add_child(selector)
	selector.setup(mode, title)
	selector.slot_selected.connect(func(slot): _on_slot_selected(slot, mode))
	selector.cancelled.connect(func(): selector.queue_free())

func _on_slot_selected(slot: int, mode: String):
	if mode == "new_game":
		if SaveManager.has_save_in_slot(slot):
			_confirm_overwrite(slot)
		else:
			_start_new_game(slot)
	elif mode == "load":
		_load_and_start_game(slot)

func _confirm_overwrite(slot: int):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Overwrite save slot %d?" % slot
	dialog.confirmed.connect(func(): _start_new_game(slot))
	add_child(dialog)
	dialog.popup_centered()

func _start_new_game(slot: int):
	SaveManager.create_new_save(slot)
	SaveManager.start_autosave()
	var start_map = SaveManager.get_current_map()
	var map_path = SaveManager.get_map_scene_path(start_map)
	get_tree().change_scene_to_file(map_path)

func _load_and_start_game(slot: int):
	if await SaveManager.load_game(slot):
		SaveManager.start_autosave()
		var last_map = SaveManager.get_current_map()
		var map_path = SaveManager.get_map_scene_path(last_map)
		get_tree().change_scene_to_file(map_path)
	else:
		print("Failed to load save")

func _on_options_pressed():
	get_tree().change_scene_to_file("res://Sceans/MainMenu/options_scean.tscn")

func _on_quit_pressed():
	get_tree().quit()
