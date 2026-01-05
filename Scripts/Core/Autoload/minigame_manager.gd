extends Node
## MinigameManager - Minigame Loading & Management
## AutoLoad Singleton: Handles entering/exiting minigames, preserves position

#region Signals
signal minigame_starting(minigame_id: String)
signal minigame_started(minigame_id: String)
signal minigame_completed(minigame_id: String, result: MinigameResult)
signal minigame_failed(minigame_id: String, reason: String)
signal minigame_exited(minigame_id: String)
#endregion

#region State Variables
var current_minigame_id: String = ""
var current_minigame_map: String = ""
var current_minigame_instance: Node = null
var current_minigame_data: Dictionary = {}

# Saved state for returning from minigame
var saved_map: String = ""
var saved_scene_path: String = ""
var saved_position: Vector2 = Vector2.ZERO
var saved_player_facing: Vector2 = Vector2.DOWN

var is_in_minigame: bool = false
#endregion

#region Minigame Registry
# Stores info about all available minigames
var minigame_registry: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_minigame_registry()
	print("[MinigameManager] Initialized")


func _load_minigame_registry() -> void:
	"""Load all minigame manifests into registry"""
	# You can populate this from files or hardcode
	# Example entries - replace with your actual minigames
	minigame_registry = {
		# Bhaktapur minigames
		"nyatapola_temple": {
			"id": "nyatapola_temple",
			"display_name": "Nyatapola Temple Challenge",
			"description": "Climb the temple stairs while avoiding obstacles",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/nyatapola_temple_game.tscn",
			"difficulty": 1,
			"max_score": 1000,
			"time_limit": 60.0,
			"keys_available": 1,
			"base_currency_reward": 25
		},
		"bhaktapur_durbar_square": {
			"id": "bhaktapur_durbar_square",
			"display_name": "Durbar Square Puzzle",
			"description": "Solve the ancient puzzle in the square",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/durbar_square_puzzle.tscn",
			"difficulty": 2,
			"max_score": 1500,
			"time_limit": 120.0,
			"keys_available": 2,
			"base_currency_reward": 40
		},
		"musem_bhaktapur": {
			"id": "musem_bhaktapur",
			"display_name": "Museum Exploration",
			"description": "Find hidden artifacts in the museum",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/museum_exploration.tscn",
			"difficulty": 0,
			"max_score": 500,
			"time_limit": 0,  # No time limit
			"keys_available": 1,
			"base_currency_reward": 15
		},
		# Kathmandu minigames
		"kathmandu_market": {
			"id": "kathmandu_market",
			"display_name": "Market Trading",
			"map": "kathmandu",
			"scene_path": "res://Scenes/Minigames/Kathmandu/market_trading.tscn",
			"difficulty": 1,
			"max_score": 800,
			"time_limit": 90.0,
			"keys_available": 1,
			"base_currency_reward": 30
		},
		# Add more as needed
	}
	
	print("[MinigameManager] Loaded %d minigames" % minigame_registry.size())


func register_minigame(minigame_id: String, data: Dictionary) -> void:
	"""Register a new minigame (can be called by MinigameData resources)"""
	minigame_registry[minigame_id] = data
	print("[MinigameManager] Registered minigame: %s" % minigame_id)


func unregister_minigame(minigame_id: String) -> void:
	"""Remove a minigame from registry"""
	minigame_registry.erase(minigame_id)


func get_minigame_info(minigame_id: String) -> Dictionary:
	"""Get info about a minigame"""
	return minigame_registry.get(minigame_id, {})


func get_minigames_for_map(map_name: String) -> Array[Dictionary]:
	"""Get all minigames for a specific map"""
	var result: Array[Dictionary] = []
	for minigame_data in minigame_registry.values():
		if minigame_data.get("map", "") == map_name:
			result.append(minigame_data)
	return result


func get_all_minigames() -> Dictionary:
	"""Get entire registry"""
	return minigame_registry
#endregion

#region Enter Minigame
func start_minigame(minigame_id: String, entry_position: Vector2 = Vector2.ZERO, player_facing: Vector2 = Vector2.DOWN) -> bool:
	"""
	Start a minigame.
	Call this from minigame trigger zones.
	"""
	if is_in_minigame:
		push_warning("[MinigameManager] Already in a minigame!")
		return false
	
	if not minigame_registry.has(minigame_id):
		push_error("[MinigameManager] Unknown minigame: %s" % minigame_id)
		return false
	
	var minigame_data = minigame_registry[minigame_id]
	var scene_path = minigame_data.get("scene_path", "")
	
	if scene_path.is_empty():
		push_error("[MinigameManager] No scene path for minigame: %s" % minigame_id)
		return false
	
	if not ResourceLoader.exists(scene_path):
		push_error("[MinigameManager] Scene not found: %s" % scene_path)
		return false
	
	# Save current state
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		saved_map = game_manager.current_map
		saved_scene_path = _get_current_scene_path()
	else:
		saved_map = ""
		saved_scene_path = ""
	
	saved_position = entry_position if entry_position != Vector2.ZERO else _get_player_position()
	saved_player_facing = player_facing
	
	# Store map position in PlayerData
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and not saved_map.is_empty():
		player_data.save_map_position(saved_map, saved_position)
	
	current_minigame_id = minigame_id
	current_minigame_map = minigame_data.get("map", saved_map)
	current_minigame_data = minigame_data
	
	minigame_starting.emit(minigame_id)
	print("[MinigameManager] Starting minigame: %s (saved pos: %s)" % [minigame_id, saved_position])
	
	# Load minigame scene
	_load_minigame_scene(scene_path)
	
	return true


func _load_minigame_scene(scene_path: String) -> void:
	"""Load the minigame scene"""
	is_in_minigame = true
	
	# Notify GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("set_minigame_state"):
		game_manager.set_minigame_state(true)
	
	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[MinigameManager] Failed to load minigame scene: %d" % error)
		is_in_minigame = false
		return
	
	# Wait for scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Connect to minigame
	_connect_to_minigame()
	
	minigame_started.emit(current_minigame_id)
	print("[MinigameManager] Minigame loaded: %s" % current_minigame_id)


func _connect_to_minigame() -> void:
	"""Connect to the loaded minigame's signals"""
	var root = get_tree().current_scene
	if not root:
		return
	
	# Find the minigame root node (should extend MinigameBase)
	current_minigame_instance = root
	
	if root.has_method("_initialize_minigame"):
		# Connect signals
		if root.has_signal("completed") and not root.completed.is_connected(_on_minigame_completed):
			root.completed.connect(_on_minigame_completed)
		if root.has_signal("failed") and not root.failed.is_connected(_on_minigame_failed):
			root.failed.connect(_on_minigame_failed)
		if root.has_signal("exited") and not root.exited.is_connected(_on_minigame_exited):
			root.exited.connect(_on_minigame_exited)
		
		# Initialize the minigame
		root._initialize_minigame(_get_minigame_init_data())
	else:
		push_warning("[MinigameManager] Minigame scene doesn't have _initialize_minigame method")


func _get_minigame_init_data() -> Dictionary:
	"""Data passed to minigame on start"""
	var player_data = get_node_or_null("/root/PlayerData")
	var record_key = current_minigame_id
	
	return {
		"minigame_id": current_minigame_id,
		"minigame_data": current_minigame_data,
		"player_name": player_data.player_name if player_data else "Player",
		"player_id": player_data.player_id if player_data else "",
		"is_replay": player_data.is_minigame_completed(current_minigame_id) if player_data else false,
		"previous_best": player_data.minigame_records.get(record_key, {}) if player_data else {},
		"map_name": current_minigame_map
	}


func _get_player_position() -> Vector2:
	"""Get current player position"""
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.current_player:
		return game_manager.current_player.global_position
	return Vector2.ZERO


func _get_current_scene_path() -> String:
	"""Get path of current scene"""
	var current = get_tree().current_scene
	if current:
		return current.scene_file_path
	return ""
#endregion

#region Exit Minigame
func exit_minigame(result: MinigameResult = null) -> void:
	"""
	Exit current minigame and return to map.
	Called by minigame when complete or by player quitting.
	"""
	if not is_in_minigame:
		push_warning("[MinigameManager] Not in a minigame!")
		return
	
	var minigame_id = current_minigame_id
	
	# Process result if provided
	if result:
		_process_minigame_result(result)
		
		# Submit score online
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.submit_minigame_result(minigame_id, result)
	
	# Clear state
	current_minigame_instance = null
	current_minigame_id = ""
	current_minigame_data = {}
	is_in_minigame = false
	
	# Notify GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("set_minigame_state"):
		game_manager.set_minigame_state(false)
	
	minigame_exited.emit(minigame_id)
	
	# Return to map at saved position
	_return_to_map()


func _return_to_map() -> void:
	"""Return to the map at saved position"""
	print("[MinigameManager] Returning to %s at %s" % [saved_map, saved_position])
	
	var game_manager = get_node_or_null("/root/GameManager")
	
	if game_manager:
		# Use GameManager's scene change with position
		if game_manager.has_method("change_map"):
			game_manager.change_map(saved_map, saved_position)
		elif game_manager.has_method("change_scene"):
			game_manager._pending_player_position = saved_position
			game_manager.change_scene(saved_scene_path)
		else:
			# Fallback: direct scene change
			_direct_return_to_map()
	else:
		_direct_return_to_map()


func _direct_return_to_map() -> void:
	"""Direct return without GameManager"""
	if saved_scene_path.is_empty():
		push_error("[MinigameManager] No saved scene to return to!")
		return
	
	get_tree().change_scene_to_file(saved_scene_path)
	
	# Wait and position player
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = _find_player()
	if player and saved_position != Vector2.ZERO:
		player.global_position = saved_position


func _find_player() -> Node2D:
	"""Find player in current scene"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _process_minigame_result(result: MinigameResult) -> void:
	"""Process the minigame result and update PlayerData"""
	var player_data = get_node_or_null("/root/PlayerData")
	if not player_data:
		return
	
	if result.success:
		# Mark as complete
		player_data.complete_minigame(
			result.minigame_id if not result.minigame_id.is_empty() else current_minigame_id,
			current_minigame_map,
			{
				"score": result.score,
				"time": result.time_taken,
				"stars": result.stars
			}
		)
		
		# Award keys
		for key_id in result.keys_found:
			player_data.collect_key(key_id, current_minigame_map)
		
		# Award items
		for item in result.items_awarded:
			if item.get("special", false):
				player_data.add_special_item(item.get("id", ""))
			else:
				player_data.add_item(item.get("id", ""), item.get("amount", 1))
		
		# Award currency
		if result.currency_awarded > 0:
			player_data.add_currency(result.currency_awarded)
		
		# Auto-save
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("auto_save"):
			game_manager.auto_save()
		
		minigame_completed.emit(current_minigame_id, result)
		print("[MinigameManager] Minigame completed: %s (Score: %d, Stars: %d)" % [
			current_minigame_id, result.score, result.stars
		])
	else:
		minigame_failed.emit(current_minigame_id, result.failure_reason)
		print("[MinigameManager] Minigame failed: %s (%s)" % [current_minigame_id, result.failure_reason])
#endregion

#region Signal Handlers (from minigame)
func _on_minigame_completed(result: MinigameResult) -> void:
	"""Called when minigame emits completed signal"""
	exit_minigame(result)


func _on_minigame_failed(reason: String) -> void:
	"""Called when minigame emits failed signal"""
	var result = MinigameResult.new()
	result.success = false
	result.failure_reason = reason
	exit_minigame(result)


func _on_minigame_exited() -> void:
	"""Called when player exits minigame early"""
	exit_minigame(null)
#endregion

#region Quick Exit (ESC handling)
func request_exit() -> void:
	"""Request to exit current minigame (called from pause menu or ESC)"""
	if not is_in_minigame:
		return
	
	# Ask minigame to handle exit
	if current_minigame_instance and current_minigame_instance.has_method("request_exit"):
		current_minigame_instance.request_exit()
	else:
		exit_minigame(null)


func force_exit() -> void:
	"""Force exit minigame immediately"""
	exit_minigame(null)
#endregion

#region Utility
func get_current_minigame_id() -> String:
	return current_minigame_id


func get_current_minigame_data() -> Dictionary:
	return current_minigame_data


func get_saved_position() -> Vector2:
	return saved_position


func get_saved_map() -> String:
	return saved_map
#endregion
