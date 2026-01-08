extends Node
## GameManager - FIXED scene/map tracking

#region Scene Paths
const MAIN_MENU_SCENE: String = "res://Scenes/Core/UI/main_menu.tscn"
const WAKE_UP_SCENE: String = "res://Scenes/MainCharacter/main_character_house.tscn"
const PROLOGUE_SCENE: String = "res://Scenes/Core/Maps/Prologue/prlogue_map.tscn"

const MAP_SCENES: Dictionary = {
	"prlogue_map": "res://Scenes/Core/Maps/Prologue/prlogue_map.tscn",
	"prologue_map": "res://Scenes/Core/Maps/Prologue/prlogue_map.tscn",
	"bhaktapur": "res://Scenes/Core/Maps/bhaktapur.tscn",
	"kathmandu": "res://Scenes/Core/Maps/kathmandu.tscn",
	"patan": "res://Scenes/Core/Maps/patan.tscn",
	"kathmandu_university": "res://Scenes/Core/Maps/kathmandu_university.tscn",
	"main_character_house": "res://Scenes/MainCharacter/main_character_house.tscn"
}
#endregion

#region Game State
enum GameState { MENU, PLAYING, PAUSED, CUTSCENE, LOADING }

var current_state: GameState = GameState.MENU
var current_map: String = ""
var current_player: CharacterBody2D = null
var current_spawn_point: String = ""
var is_new_game: bool = true
#endregion

#region Signals
signal game_started
signal game_continued
signal game_paused(is_paused: bool)
signal scene_changed(new_scene: String)
#endregion

var _pending_player_position: Vector2 = Vector2.ZERO
var _loading_from_save: bool = false

func is_playing() -> bool:
	"""Check if game is in playing state (for external checks)"""
	return current_state == GameState.PLAYING

func _ready() -> void:
	print("[GameManager] Initialized")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_state == GameState.PLAYING:
		# Check if we're in a map scene - if so, don't pause
		if _is_in_map_scene():
			return  # Don't pause in maps
		
		toggle_pause()

func _is_in_map_scene() -> bool:
	"""Check if current scene is a map (overworld) scene"""
	# Check the current_map variable
	if not current_map.is_empty():
		# These are map scenes where pause should NOT work
		var map_scenes = [
			"prlogue_map",
			"prologue_map", 
			"bhaktapur",
			"kathmandu",
			"patan",
			"kathmandu_university"
		]
		
		if current_map in map_scenes:
			return true
	
	# Fallback: check scene name
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "map" in scene_name or "bhaktapur" in scene_name or "kathmandu" in scene_name or "patan" in scene_name:
			return true
	
	return false

#region Game Flow
func start_new_game() -> void:
	"""Start a fresh new game"""
	print("[GameManager] Starting new game...")
	is_new_game = true
	current_map = ""
	current_spawn_point = ""
	_pending_player_position = Vector2.ZERO
	_loading_from_save = false
	
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.has_method("reset_all"):
		player_data.reset_all()
	
	_transition_to_scene(WAKE_UP_SCENE)
	current_state = GameState.PLAYING
	game_started.emit()


func continue_game() -> void:
	"""Continue from last save"""
	print("[GameManager] ========== CONTINUE GAME ==========")
	is_new_game = false
	_loading_from_save = true
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_warning("[GameManager] No SaveManager, starting new game instead")
		start_new_game()
		return
	
	var save_data = save_manager.load_game()
	
	if save_data == null:
		print("[GameManager] No save data found, starting new game")
		start_new_game()
		return
	
	# Load PlayerData FIRST
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.has_method("load_from_dictionary"):
		var pd = save_data.get("player_data", {})
		if not pd.is_empty():
			player_data.load_from_dictionary(pd)
			print("[GameManager] ✓ PlayerData restored!")
			print("  - Total score: %d" % player_data.total_score)
			print("  - Completed minigames: %d" % player_data.get_total_completed_minigames())
	
	# Get map and position from save
	var saved_map = save_data.get("current_map", "")
	print("[GameManager] Saved map name: '%s'" % saved_map)
	
	# Store position for spawning
	var pos = save_data.get("player_position", null)
	if pos is Vector2:
		_pending_player_position = pos
	elif pos is Dictionary:
		_pending_player_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	else:
		_pending_player_position = Vector2.ZERO
	
	print("[GameManager] Saved position: %s" % _pending_player_position)
	
	# Determine which scene to load
	var scene_to_load: String = ""
	
	if saved_map.is_empty() or saved_map == "main_character_house":
		print("[GameManager] No valid map, loading wake up scene")
		scene_to_load = WAKE_UP_SCENE
		current_map = "main_character_house"
	else:
		var normalized_map = _normalize_map_name(saved_map)
		current_map = normalized_map
		scene_to_load = _get_scene_path_for_map(normalized_map)
		print("[GameManager] Loading map: '%s' -> '%s'" % [normalized_map, scene_to_load])
	
	_transition_to_scene(scene_to_load)
	
	current_state = GameState.PLAYING
	game_continued.emit()
	print("[GameManager] =====================================")


func _normalize_map_name(map_name: String) -> String:
	"""Normalize map name to handle typo variants"""
	map_name = map_name.replace(".tscn", "").replace("_map", "")
	
	if "prologue" in map_name.to_lower():
		return "prlogue_map"
	
	match map_name.to_lower():
		"prlogue", "prologue":
			return "prlogue_map"
		"bhaktapur":
			return "bhaktapur"
		"kathmandu":
			return "kathmandu"
		"patan":
			return "patan"
		"kathmandu_university":
			return "kathmandu_university"
	
	return map_name


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


#region Scene Management - FIXED
func change_scene(scene_path: String, spawn_point: String = "") -> void:
	"""Change to a new scene with optional spawn point"""
	current_spawn_point = spawn_point
	_transition_to_scene(scene_path)


func _transition_to_scene(scene_path: String) -> void:
	"""Internal scene transition with validation"""
	print("[GameManager] Transitioning to: %s" % scene_path)
	
	if not ResourceLoader.exists(scene_path):
		push_error("[GameManager] Scene not found: %s" % scene_path)
		return
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[GameManager] Failed to change scene: %d" % error)
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		_on_scene_loaded()
		scene_changed.emit(current_map)


func _on_scene_loaded() -> void:
	"""Called after scene transition completes - FIXED to always update current_map"""
	await get_tree().process_frame
	
	# ========== FIX: ALWAYS update current_map from actual loaded scene ==========
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path and not scene_path.is_empty():
			var extracted_map = _extract_map_name(scene_path)
			
			# Only override if we're NOT loading from save, OR if loading from save and current_map is empty
			if not _loading_from_save or current_map.is_empty():
				current_map = extracted_map
				print("[GameManager] current_map set from scene: %s" % current_map)
			else:
				# When loading from save, verify the extracted map matches
				if extracted_map != current_map:
					print("[GameManager] WARNING: Scene (%s) doesn't match saved map (%s)" % [extracted_map, current_map])
					# Use the actual scene name as it's more reliable
					current_map = extracted_map
					print("[GameManager] Corrected current_map to: %s" % current_map)
				else:
					print("[GameManager] ✓ Scene matches saved map: %s" % current_map)
	
	_loading_from_save = false  # Reset flag
	# ============================================================================
	
	# Find and register player
	current_player = _find_player()
	
	if current_player:
		print("[GameManager] ✓ Player found: %s" % current_player.name)
		
		# Apply pending position if continuing from save
		if _pending_player_position != Vector2.ZERO:
			await get_tree().process_frame
			current_player.global_position = _pending_player_position
			print("[GameManager] ✓ Applied saved position: %s" % _pending_player_position)
			_pending_player_position = Vector2.ZERO
		elif current_spawn_point != "":
			var spawn = _find_spawn_point(current_spawn_point)
			if spawn:
				current_player.global_position = spawn.global_position
				print("[GameManager] ✓ Spawned at: %s" % current_spawn_point)
			current_spawn_point = ""
		
		# Save position to PlayerData
		var player_data = get_node_or_null("/root/PlayerData")
		if player_data and not current_map.is_empty():
			player_data.save_map_position(current_map, current_player.global_position)
			print("[GameManager] ✓ Position saved to PlayerData for map: %s" % current_map)
	else:
		push_warning("[GameManager] ✗ Player not found in scene!")


func _find_player() -> CharacterBody2D:
	"""Find player node in current scene"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody2D:
		return players[0]
	
	var root = get_tree().current_scene
	if not root:
		return null
	
	for name in ["Player", "MainCharacter", "Character"]:
		var node = root.get_node_or_null(name)
		if node and node is CharacterBody2D:
			return node
	
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
	
	var spawns = root.get_node_or_null("SpawnPoints")
	if spawns:
		var point = spawns.get_node_or_null(point_name)
		if point:
			return point
	
	return root.get_node_or_null(point_name)


func _extract_map_name(scene_path: String) -> String:
	"""Extract map name from scene path"""
	var filename = scene_path.get_file()
	return filename.get_basename()


func _get_scene_path_for_map(map_name: String) -> String:
	"""Convert map name to full scene path"""
	if MAP_SCENES.has(map_name):
		return MAP_SCENES[map_name]
	
	var paths = [
		"res://Scenes/Core/Maps/%s.tscn" % map_name,
		"res://Scenes/Core/Maps/Prologue/%s.tscn" % map_name,
		"res://Scenes/Maps/%s.tscn" % map_name,
		"res://Scenes/MainCharacter/%s.tscn" % map_name,
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			print("[GameManager] ✓ Found scene at: %s" % path)
			return path
	
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


#region Save Integration - FIXED
func save_current_game(slot: int = 1) -> bool:
	"""Save current game state"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_error("[GameManager] No SaveManager available")
		return false
	
	return save_manager.save_game(slot)


func auto_save() -> void:
	"""Trigger auto-save - FIXED to use actual current scene"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_warning("[GameManager] No SaveManager for auto-save")
		return
	
	var position = Vector2.ZERO
	var map_name = current_map
	
	# Get position from current player
	if current_player:
		position = current_player.global_position
		print("[GameManager] Auto-save position from player: %s" % position)
	else:
		# Fallback: use saved position from PlayerData
		var player_data = get_node_or_null("/root/PlayerData")
		if player_data and not map_name.is_empty():
			position = player_data.get_map_position(map_name)
			print("[GameManager] Auto-save position from PlayerData: %s" % position)
	
	# ========== FIX: Verify map_name from actual scene ==========
	if map_name.is_empty():
		var current_scene = get_tree().current_scene
		if current_scene:
			map_name = _extract_map_name(current_scene.scene_file_path)
			print("[GameManager] Auto-save extracted map from scene: %s" % map_name)
	
	# Fallback to MinigameManager if still empty
	if map_name.is_empty():
		var minigame_manager = get_node_or_null("/root/MinigameManager")
		if minigame_manager:
			map_name = minigame_manager.saved_map
			if position == Vector2.ZERO:
				position = minigame_manager.saved_position
	
	if map_name.is_empty():
		push_warning("[GameManager] Cannot auto-save: no map name")
		return
	
	# Save to auto-save slot
	save_manager.auto_save(map_name, position)
	print("[GameManager] ✓ Auto-saved: %s at %s" % [map_name, position])
	
	# Also update most recent manual save
	var most_recent = save_manager._get_most_recent_slot()
	if most_recent > 0:
		save_manager.save_game(most_recent)
		print("[GameManager] ✓ Also saved to slot %d" % most_recent)
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
