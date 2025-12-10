extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE = "savegame.tres"
const AUTOSAVE_INTERVAL = 60.0  # Autosave every 60 seconds

var current_save: GameSaveData
var is_game_loaded: bool = false
var autosave_timer: Timer
var play_time_timer: Timer

func _ready():
	# Create save directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	
	# Setup autosave timer
	autosave_timer = Timer.new()
	autosave_timer.wait_time = AUTOSAVE_INTERVAL
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(_on_autosave)
	add_child(autosave_timer)
	
	# Setup play time tracker
	play_time_timer = Timer.new()
	play_time_timer.wait_time = 1.0
	play_time_timer.one_shot = false
	play_time_timer.timeout.connect(_on_play_time_tick)
	add_child(play_time_timer)

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_FILE)

func create_new_save():
	current_save = GameSaveData.new()
	current_save.save_version = 1
	current_save.play_time_seconds = 0.0
	current_save.current_map = "bhaktapur"
	
	# Initialize map data
	current_save.kathmandu_data = MapData.new()
	current_save.kathmandu_data.map_name = "kathmandu"
	
	current_save.patan_data = MapData.new()
	current_save.patan_data.map_name = "patan"
	
	current_save.bhaktapur_data = MapData.new()
	current_save.bhaktapur_data.map_name = "bhaktapur"
	
	current_save.minigame_data = {}
	
	is_game_loaded = true
	save_game()

func save_game() -> bool:
	if current_save == null:
		push_error("Cannot save: No active save data")
		return false
	
	current_save.save_timestamp = Time.get_datetime_string_from_system()
	
	var error = ResourceSaver.save(current_save, SAVE_DIR + SAVE_FILE)
	if error != OK:
		push_error("Failed to save game: " + str(error))
		return false
	
	print("Game saved successfully at: " + current_save.save_timestamp)
	return true

func load_game() -> bool:
	var save_path = SAVE_DIR + SAVE_FILE
	
	if not ResourceLoader.exists(save_path):
		push_error("Save file does not exist")
		return false
	
	current_save = ResourceLoader.load(save_path)
	
	if current_save == null:
		push_error("Failed to load save file")
		return false
	
	is_game_loaded = true
	print("Game loaded successfully from: " + current_save.save_timestamp)
	return true

func start_autosave():
	if not autosave_timer.is_stopped():
		return
	autosave_timer.start()
	play_time_timer.start()
	print("Autosave enabled")

func stop_autosave():
	autosave_timer.stop()
	play_time_timer.stop()
	print("Autosave disabled")

func _on_autosave():
	if is_game_loaded and current_save != null:
		save_game()
		print("Autosave triggered")

func _on_play_time_tick():
	if current_save != null:
		current_save.play_time_seconds += 1.0

func get_map_data(map_name: String) -> MapData:
	if current_save == null:
		return null
	
	match map_name.to_lower():
		"kathmandu": return current_save.kathmandu_data
		"patan": return current_save.patan_data
		"bhaktapur": return current_save.bhaktapur_data
	
	push_error("Invalid map name: " + map_name)
	return null

func set_current_map(map_name: String):
	if current_save != null:
		current_save.current_map = map_name

func get_current_map() -> String:
	if current_save != null:
		return current_save.current_map
	return ""

func set_minigame_completed(map_name: String, minigame_id: String, completed: bool):
	var map_data = get_map_data(map_name)
	if map_data:
		map_data.minigames_completed[minigame_id] = completed
		print("Minigame '%s' on map '%s' set to completed: %s" % [minigame_id, map_name, completed])

func is_minigame_completed(map_name: String, minigame_id: String) -> bool:
	var map_data = get_map_data(map_name)
	if map_data and map_data.minigames_completed.has(minigame_id):
		return map_data.minigames_completed[minigame_id]
	return false

func save_minigame_data(minigame_id: String, data: MinigameData):
	if current_save:
		current_save.minigame_data[minigame_id] = data

func get_minigame_data(minigame_id: String) -> MinigameData:
	if current_save and current_save.minigame_data.has(minigame_id):
		return current_save.minigame_data[minigame_id]
	return null

func set_player_position(map_name: String, position: Vector2):
	var map_data = get_map_data(map_name)
	if map_data:
		map_data.last_position = position

func get_player_position(map_name: String) -> Vector2:
	var map_data = get_map_data(map_name)
	if map_data:
		return map_data.last_position
	return Vector2.ZERO

func get_play_time_formatted() -> String:
	if current_save == null:
		return "00:00:00"
	
	var total_seconds = int(current_save.play_time_seconds)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
	
func debug_save_data():
	if current_save == null:
		print("No save data loaded")
		return
	
	print("=== SAVE DATA DEBUG ===")
	print("Current map: " + current_save.current_map)
	print("Play time: " + str(current_save.play_time_seconds))
	print("Save timestamp: " + current_save.save_timestamp)
	print("Kathmandu minigames: " + str(current_save.kathmandu_data.minigames_completed))
	print("Patan minigames: " + str(current_save.patan_data.minigames_completed))
	print("Bhaktapur minigames: " + str(current_save.bhaktapur_data.minigames_completed))
	print("======================")
