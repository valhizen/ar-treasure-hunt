extends Node
## GameManager - Core game state and flow controller
## AutoLoad Singleton: Manages game state, scene transitions, player reference

#region Signals
signal game_started
signal game_continued
signal game_paused(is_paused: bool)
signal scene_changed(new_scene: String)
#endregion

#region Scene Paths
const MAIN_MENU_SCENE: String = "res://Scenes/Core/UI/main_menu.tscn"
const WAKE_UP_SCENE: String = "res://Scenes/MainCharacter/main_character_house.tscn"
const PROLOGUE_SCENE: String = "res://Scenes/Core/Maps/Prologue/prlogue_map.tscn"
#endregion

#region Game State
enum GameState { MENU, PLAYING, PAUSED, CUTSCENE, LOADING }

var current_state: GameState = GameState.MENU
var current_map: String = ""
var current_player: CharacterBody2D = null
var current_spawn_point: String = ""

## Is this a new game or continued?
var is_new_game: bool = true
#endregion


func _ready() -> void:
	print("[GameManager] Initialized")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused


func _input(event: InputEvent) -> void:
	# Pause toggle
	if event.is_action_pressed("ui_cancel") and current_state == GameState.PLAYING:
		toggle_pause()


#region Game Flow - Public API
func start_new_game() -> void:
	"""Start a fresh new game"""
	print("[GameManager] Starting new game...")
	is_new_game = true
	current_map = ""
	current_spawn_point = ""
	
	# Reset player data
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.has_method("reset_all"):
		player_data.reset_all()
	
	# Go to wake up scene
	_transition_to_scene(WAKE_UP_SCENE)
	
	current_state = GameState.PLAYING
	game_started.emit()


func continue_game() -> void:
	"""Continue from last save"""
	print("[GameManager] Continuing game...")
	is_new_game = false
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_warning("[GameManager] No SaveManager, starting new game instead")
		start_new_game()
		return
	
	var save_data = save_manager.load_game()
	
	# Debug: Print save contents
	print("========== SAVE FILE DEBUG ==========")
	if save_data == null:
		print("save_data is NULL!")
		print("======================================")
		start_new_game()
		return
	
	print("Keys in save_data: ", save_data.keys())
	print("current_map: ", save_data.get("current_map", "MISSING"))
	print("player_position: ", save_data.get("player_position", "MISSING"))
	var pd = save_data.get("player_data", {})
	print("player_data empty: ", pd.is_empty())
	print("completed_minigames: ", pd.get("completed_minigames", {}))
	print("======================================")
	
	# Load player data - FIX: correct method name
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.has_method("load_from_dictionary"):
		if not pd.is_empty():
			player_data.load_from_dictionary(pd)
			print("[GameManager] PlayerData restored!")
			print("  - Completed minigames: ", player_data.get_total_completed_minigames())
			print("  - Total score: ", player_data.total_score)
		else:
			push_warning("[GameManager] No player_data in save!")
	
	# Get map to load
	current_map = save_data.get("current_map", "")
	
	# Store player position for spawning
	var pos = save_data.get("player_position", null)
	if pos is Vector2:
		_pending_player_position = pos
	elif pos is Dictionary:
		_pending_player_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	else:
		_pending_player_position = Vector2.ZERO
	
	if current_map == "" or current_map == "main_character_house":
		print("[GameManager] No map in save, going to wake up scene")
		_transition_to_scene(WAKE_UP_SCENE)
	else:
		var scene_path = _get_scene_path_for_map(current_map)
		print("[GameManager] Loading map: ", current_map, " -> ", scene_path)
		_transition_to_scene(scene_path)
	
	current_state = GameState.PLAYING
	game_continued.emit()

func quit_game() -> void:
	"""Quit to desktop"""
	print("[GameManager] Quitting game...")
	get_tree().quit()


func return_to_menu() -> void:
	"""Return to main menu"""
	print("[GameManager] Returning to menu...")
	current_state = GameState.MENU
	get_tree().paused = false
	_transition_to_scene(MAIN_MENU_SCENE)
#endregion


#region Scene Management
var _pending_player_position: Vector2 = Vector2.ZERO

func change_scene(scene_path: String, spawn_point: String = "") -> void:
	"""Change to a new scene with optional spawn point"""
	current_spawn_point = spawn_point
	_transition_to_scene(scene_path)


func _transition_to_scene(scene_path: String) -> void:
	"""Internal scene transition with validation"""
	print("[GameManager] Transitioning to: %s" % scene_path)
	
	# Validate scene exists
	if not ResourceLoader.exists(scene_path):
		push_error("[GameManager] Scene not found: %s" % scene_path)
		return
	
	# Update current map name
	current_map = _extract_map_name(scene_path)
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[GameManager] Failed to change scene: %d" % error)
	else:
		# Wait for scene to load then setup
		await get_tree().process_frame
		await get_tree().process_frame
		_on_scene_loaded()
		scene_changed.emit(current_map)


# In GameManager - update _on_scene_loaded()
func _on_scene_loaded() -> void:
	"""Called after scene transition completes"""
	await get_tree().process_frame
	
	# ALWAYS set current_map from the loaded scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path and not scene_path.is_empty():
			current_map = _extract_map_name(scene_path)
			print("[GameManager] current_map set to: ", current_map)
	
	# Find and register player
	current_player = _find_player()
	
	if current_player:
		print("[GameManager] Player found: ", current_player.name)
		
		# Apply pending position if continuing
		if _pending_player_position != Vector2.ZERO:
			current_player.global_position = _pending_player_position
			_pending_player_position = Vector2.ZERO
			print("[GameManager] Applied saved position")
		elif current_spawn_point != "":
			var spawn = _find_spawn_point(current_spawn_point)
			if spawn:
				current_player.global_position = spawn.global_position
				print("[GameManager] Spawned at: ", current_spawn_point)
			current_spawn_point = ""
		
		# Save position to PlayerData
		var player_data = get_node_or_null("/root/PlayerData")
		if player_data and not current_map.is_empty():
			player_data.save_map_position(current_map, current_player.global_position)

func _find_player() -> CharacterBody2D:
	"""Find player node in current scene"""
	# Check group first
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody2D:
		return players[0]
	
	# Search by common names
	var root = get_tree().current_scene
	if not root:
		return null
	
	for name in ["Player", "MainCharacter", "Character"]:
		var node = root.get_node_or_null(name)
		if node and node is CharacterBody2D:
			return node
	
	# Deep search
	return _find_node_by_class(root, "CharacterBody2D")


func _find_node_by_class(node: Node, class_name_str: String) -> CharacterBody2D:
	if node is CharacterBody2D and node.is_in_group("player"):
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _find_spawn_point(point_name: String) -> Node2D:
	"""Find a spawn point by name"""
	var root = get_tree().current_scene
	if not root:
		return null
	
	# Check SpawnPoints container
	var spawns = root.get_node_or_null("SpawnPoints")
	if spawns:
		var point = spawns.get_node_or_null(point_name)
		if point:
			return point
	
	# Direct search
	return root.get_node_or_null(point_name)


func _extract_map_name(scene_path: String) -> String:
	"""Extract map name from scene path"""
	var filename = scene_path.get_file()
	return filename.get_basename()


func _get_scene_path_for_map(map_name: String) -> String:
	"""Convert map name to full scene path"""
	# Try common locations
	var paths = [
		"res://Scenes/Core/Maps/%s.tscn" % map_name,
		"res://Scenes/Core/Maps/Prologue/%s.tscn" % map_name,
		"res://Scenes/Maps/%s.tscn" % map_name,
		"res://Scenes/MainCharacter/%s.tscn" % map_name,
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	
	# Return default
	push_warning("[GameManager] Could not find scene for map: %s" % map_name)
	return WAKE_UP_SCENE
#endregion


#region Pause System
func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		set_paused(true)
	elif current_state == GameState.PAUSED:
		set_paused(false)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	current_state = GameState.PAUSED if paused else GameState.PLAYING
	game_paused.emit(paused)
	print("[GameManager] Game %s" % ("paused" if paused else "unpaused"))
#endregion


#region Save Integration
func save_current_game(slot: int = 1) -> bool:
	"""Save current game state"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_error("[GameManager] No SaveManager available")
		return false
	
	return save_manager.save_game(slot)


func auto_save() -> void:
	"""Trigger auto-save"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_warning("[GameManager] No SaveManager for auto-save")
		return
	
	# Get position from current_player OR from PlayerData's saved position
	var position = Vector2.ZERO
	var map_name = current_map
	
	if current_player:
		position = current_player.global_position
	else:
		# Fallback: use saved position from PlayerData
		var player_data = get_node_or_null("/root/PlayerData")
		if player_data and not map_name.is_empty():
			position = player_data.get_map_position(map_name)
	
	# If we still don't have a map name, try to get it from MinigameManager
	if map_name.is_empty():
		var minigame_manager = get_node_or_null("/root/MinigameManager")
		if minigame_manager:
			map_name = minigame_manager.saved_map
			if position == Vector2.ZERO:
				position = minigame_manager.saved_position
	
	if map_name.is_empty():
		push_warning("[GameManager] Cannot auto-save: no map name")
		return
	
	# Save to both auto-save slot AND most recent manual slot
	save_manager.auto_save(map_name, position)
	
	# Also update the most recent manual save slot (1-4)
	var most_recent = save_manager._get_most_recent_slot()
	if most_recent > 0:  # Don't overwrite if only auto-save exists
		save_manager.save_game(most_recent)
		print("[GameManager] Auto-saved to slot 0 and slot ", most_recent)
	else:
		print("[GameManager] Auto-saved to slot 0")
#endregion


#region Spawn Point Helper
func set_spawn_point(point_name: String) -> void:
	"""Set spawn point for next scene"""
	current_spawn_point = point_name


func get_spawn_point() -> String:
	"""Get and clear current spawn point"""
	var point = current_spawn_point
	current_spawn_point = ""
	return point
#endregion
