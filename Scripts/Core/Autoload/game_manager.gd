extends Node
## GameManager - Core game state management
## AutoLoad Singleton: Manages game flow, map transitions, pause state

#region Signals
signal game_started
signal game_paused
signal game_resumed
signal map_changed(from_map: String, to_map: String)
signal map_load_started(map_name: String)
signal map_load_completed(map_name: String)
#endregion

#region Enums
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	IN_MINIGAME,
	LOADING,
	CUTSCENE
}

enum Map {
	BHAKTAPUR,
	KATHMANDU,
	PATAN,
	KATHMANDU_UNIVERSITY
}
#endregion

#region Constants
const MAP_SCENES: Dictionary = {
	"bhaktapur": "res://Sceans/Core/Maps/bhaktapur.tscn",
	"kathmandu": "res://Sceans/Core/Maps/kathmandu.tscn",
	"patan": "res://Sceans/Core/Maps/patan.tscn",
	"kathmandu_university": "res://Sceans/Maps/kathmandu_university.tscn"
}

const MAP_PROGRESSION: Array[String] = [
	"bhaktapur",
	"kathmandu",
	"patan",
	"kathmandu_university"
]

const STARTING_MAP: String = "bhaktapur"
const MAIN_MENU_SCENE: String = "res://Sceans/Core/MainMenu/main_menu.tscn"
#endregion

#region State Variables
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU
var current_map: String = ""
var is_new_game: bool = false

# Reference to current map node (set by map when it loads)
var current_map_node: Node = null
var current_player: CharacterBody2D = null
#endregion

#region Lifecycle
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep running even when paused
	print("[GameManager] Initialized")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_handle_escape()
#endregion

#region Game Flow
func start_new_game() -> void:
	"""Start a fresh game from the beginning"""
	is_new_game = true
	PlayerData.reset_all()
	PlayerData.unlock_map("bhaktapur")
	
	change_map(STARTING_MAP)
	game_started.emit()
	print("[GameManager] New game started")
	
	await get_tree().create_timer(1.0).timeout  # Wait for map to load
	trigger_autosave()
	print("[GameManager] Initial auto-save created")


func continue_game() -> void:
	"""Continue from last save"""
	is_new_game = false
	var save_data = SaveManager.load_game()
	
	if save_data:
		PlayerData.load_from_dictionary(save_data["player_data"])
		change_map(save_data["current_map"], save_data["player_position"])
		game_started.emit()
		print("[GameManager] Game continued from save")
	else:
		push_warning("[GameManager] No save found, starting new game")
		start_new_game()


func load_specific_save(slot_index: int) -> bool:
	"""Load a specific save slot"""
	var save_data = SaveManager.load_game(slot_index)
	
	if save_data:
		PlayerData.load_from_dictionary(save_data.player_data)
		change_map(save_data.current_map, save_data.player_position)
		game_started.emit()
		print("[GameManager] Loaded save slot %d" % slot_index)
		return true
	
	return false


func return_to_main_menu() -> void:
	"""Return to main menu"""
	current_state = GameState.MAIN_MENU
	current_map = ""
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	print("[GameManager] Returned to main menu")


func quit_game() -> void:
	"""Quit the application"""
	print("[GameManager] Quitting game")
	get_tree().quit()
#endregion

#region Map Management
func change_map(map_name: String, spawn_position: Vector2 = Vector2.ZERO, spawn_point_name: String = "") -> void:
	"""Change to a different map"""
	if not MAP_SCENES.has(map_name):
		push_error("[GameManager] Unknown map: %s" % map_name)
		return
	
	if not PlayerData.is_map_unlocked(map_name):
		push_warning("[GameManager] Map not unlocked: %s" % map_name)
		return
	
	var old_map = current_map
	_set_state(GameState.LOADING)
	map_load_started.emit(map_name)
	
	# Store spawn info for the map to use
	_pending_spawn_position = spawn_position
	_pending_spawn_point = spawn_point_name
	
	# Change scene
	var error = get_tree().change_scene_to_file(MAP_SCENES[map_name])
	if error != OK:
		push_error("[GameManager] Failed to load map: %s" % map_name)
		return
	
	current_map = map_name
	
	# Wait for scene to be ready
	await get_tree().process_frame
	
	_set_state(GameState.PLAYING)
	map_changed.emit(old_map, map_name)
	map_load_completed.emit(map_name)
	
	print("[GameManager] Changed map: %s -> %s" % [old_map, map_name])


# Pending spawn data (used by map when it initializes)
var _pending_spawn_position: Vector2 = Vector2.ZERO
var _pending_spawn_point: String = ""

func get_spawn_position() -> Vector2:
	"""Get the pending spawn position (called by map on load)"""
	var pos = _pending_spawn_position
	_pending_spawn_position = Vector2.ZERO
	return pos


func get_spawn_point_name() -> String:
	"""Get the pending spawn point name (called by map on load)"""
	var point = _pending_spawn_point
	_pending_spawn_point = ""
	return point


func register_map(map_node: Node) -> void:
	"""Called by map scene when it's ready"""
	current_map_node = map_node
	print("[GameManager] Map registered: %s" % map_node.name)


func register_player(player: CharacterBody2D) -> void:
	"""Called by player when spawned"""
	current_player = player
	print("[GameManager] Player registered")


func get_next_map() -> String:
	"""Get the next map in progression"""
	var current_index = MAP_PROGRESSION.find(current_map)
	if current_index >= 0 and current_index < MAP_PROGRESSION.size() - 1:
		return MAP_PROGRESSION[current_index + 1]
	return ""


func can_progress_to_next_map() -> bool:
	"""Check if player has completed enough to progress"""
	var next_map = get_next_map()
	if next_map.is_empty():
		return false
	
	# Check if requirements are met (defined per map)
	var required = get_map_progression_requirement(current_map)
	var completed = PlayerData.get_completed_minigame_count(current_map)
	
	return completed >= required


func get_map_progression_requirement(map_name: String) -> int:
	"""Get number of minigames needed to unlock next map"""
	# Configure these based on your game design
	match map_name:
		"bhaktapur":
			return 3  # Complete 3 minigames to unlock Kathmandu
		"kathmandu":
			return 3  # Complete 3 minigames to unlock Patan
		"patan":
			return 3  # Complete 3 minigames to unlock KU
		_:
			return 0
#endregion

#region Pause System
func pause_game() -> void:
	"""Pause the game"""
	if current_state == GameState.PLAYING:
		_set_state(GameState.PAUSED)
		get_tree().paused = true
		game_paused.emit()
		print("[GameManager] Game paused")


func resume_game() -> void:
	"""Resume the game"""
	if current_state == GameState.PAUSED:
		_set_state(GameState.PLAYING)
		get_tree().paused = false
		game_resumed.emit()
		print("[GameManager] Game resumed")


func toggle_pause() -> void:
	"""Toggle pause state"""
	if current_state == GameState.PAUSED:
		resume_game()
	elif current_state == GameState.PLAYING:
		pause_game()


func _handle_escape() -> void:
	"""Handle ESC key press"""
	match current_state:
		GameState.PLAYING:
			pause_game()
			# Show pause menu (emit signal or call UI directly)
		GameState.PAUSED:
			resume_game()
		GameState.IN_MINIGAME:
			# Let MinigameManager handle it
			pass
#endregion

#region State Management
func _set_state(new_state: GameState) -> void:
	"""Internal state setter"""
	previous_state = current_state
	current_state = new_state


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_paused() -> bool:
	return current_state == GameState.PAUSED


func is_in_minigame() -> bool:
	return current_state == GameState.IN_MINIGAME


func set_minigame_state(in_minigame: bool) -> void:
	"""Called by MinigameManager"""
	if in_minigame:
		_set_state(GameState.IN_MINIGAME)
	else:
		_set_state(GameState.PLAYING)
#endregion

#region Auto-save
func trigger_autosave() -> void:
	"""Trigger an auto-save (call on map transitions, etc.)"""
	if current_state == GameState.PLAYING and not current_map.is_empty():
		var position = Vector2.ZERO
		if current_player:
			position = current_player.global_position
		SaveManager.auto_save(current_map, position)
#endregion
