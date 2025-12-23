extends Node
## MinigameManager - Minigame Loading & Management
## AutoLoad Singleton: Handles entering/exiting minigames, preserves position

#region Signals
signal minigame_starting(minigame_id: String)
signal minigame_started(minigame_id: String)
#signal minigame_completed(minigame_id: String, result: MinigameResult)
signal minigame_completed(minigame_id: String, result)
signal minigame_failed(minigame_id: String, reason: String)
signal minigame_exited(minigame_id: String)
#endregion

#region State Variables
var current_minigame_id: String = ""
var current_minigame_map: String = ""
var current_minigame_instance: Node = null

# Saved state for returning from minigame
var saved_map: String = ""
var saved_position: Vector2 = Vector2.ZERO
var saved_player_facing: Vector2 = Vector2.DOWN

var is_in_minigame: bool = false
#endregion

#region Minigame Registry
# Stores info about all available minigames
# This gets populated from manifest files or can be hardcoded
var minigame_registry: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_minigame_registry()
	print("[MinigameManager] Initialized")


func _load_minigame_registry() -> void:
	"""Load all minigame manifests into registry"""
	# You can either:
	# 1. Hardcode minigames here
	# 2. Scan directories for manifest.json files
	# 3. Load from a central config file
	
	# Example hardcoded registry (replace with your actual minigames)
	minigame_registry = {
		# Bhaktapur minigames
		"bhaktapur_pottery": {
			"id": "bhaktapur_pottery",
			"display_name": "Pottery Making",
			"map": "bhaktapur",
			"scene_path": "res://Sceans/Minigames/bhaktapur/pottery_game.tscn",
			"keys_available": 1
		},
		"bhaktapur_puzzle": {
			"id": "bhaktapur_puzzle",
			"display_name": "Temple Puzzle",
			"map": "bhaktapur",
			"scene_path": "res://Sceans/Minigames/bhaktapur/puzzle_game.tscn",
			"keys_available": 2
		},
		# Add more as developers submit them
	}


func register_minigame(minigame_id: String, data: Dictionary) -> void:
	"""Register a new minigame (can be called by map or autoload)"""
	minigame_registry[minigame_id] = data
	print("[MinigameManager] Registered minigame: %s" % minigame_id)


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
	
	# Save current state
	saved_map = GameManager.current_map
	saved_position = entry_position if entry_position != Vector2.ZERO else _get_player_position()
	saved_player_facing = player_facing
	
	# Store map position in PlayerData too
	PlayerData.save_map_position(saved_map, saved_position)
	
	current_minigame_id = minigame_id
	current_minigame_map = minigame_data.get("map", saved_map)
	
	minigame_starting.emit(minigame_id)
	print("[MinigameManager] Starting minigame: %s (saved pos: %s)" % [minigame_id, saved_position])
	
	# Load minigame scene
	_load_minigame_scene(scene_path)
	
	return true


func _load_minigame_scene(scene_path: String) -> void:
	"""Load the minigame scene"""
	is_in_minigame = true
	GameManager.set_minigame_state(true)
	
	# Option 1: Change entire scene (simpler, cleaner)
	get_tree().change_scene_to_file(scene_path)
	
	# Wait for scene to load
	await get_tree().process_frame
	
	# Find the minigame instance
	_connect_to_minigame()
	
	minigame_started.emit(current_minigame_id)
	print("[MinigameManager] Minigame loaded: %s" % current_minigame_id)


func _connect_to_minigame() -> void:
	"""Connect to the loaded minigame's signals"""
	# Find the minigame root node (should extend MinigameBase)
	await get_tree().process_frame
	
	var root = get_tree().current_scene
	if root and root.has_method("_initialize_minigame"):
		current_minigame_instance = root
		
		# Connect signals if it's a MinigameBase
		if root.has_signal("completed"):
			root.completed.connect(_on_minigame_completed)
		if root.has_signal("failed"):
			root.failed.connect(_on_minigame_failed)
		if root.has_signal("exited"):
			root.exited.connect(_on_minigame_exited)
		
		# Initialize the minigame with player data
		root._initialize_minigame(_get_minigame_init_data())
	else:
		push_warning("[MinigameManager] Minigame scene doesn't extend MinigameBase")


func _get_minigame_init_data() -> Dictionary:
	"""Data passed to minigame on start"""
	return {
		"minigame_id": current_minigame_id,
		"player_name": PlayerData.player_name,
		"player_id": PlayerData.player_id,
		"is_replay": PlayerData.is_minigame_completed(current_minigame_id, current_minigame_map),
		"previous_best": PlayerData.minigame_records.get(
			"%s/%s" % [current_minigame_map, current_minigame_id], {}
		)
	}


func _get_player_position() -> Vector2:
	"""Get current player position"""
	if GameManager.current_player:
		return GameManager.current_player.global_position
	return Vector2.ZERO
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
	
	# Clear state
	current_minigame_instance = null
	current_minigame_id = ""
	is_in_minigame = false
	GameManager.set_minigame_state(false)
	
	minigame_exited.emit(minigame_id)
	
	# Return to map at saved position
	_return_to_map()


func _return_to_map() -> void:
	"""Return to the map at saved position"""
	print("[MinigameManager] Returning to %s at %s" % [saved_map, saved_position])
	
	# Tell GameManager to load the map with our saved position
	GameManager.change_map(saved_map, saved_position)


func _process_minigame_result(result: MinigameResult) -> void:
	"""Process the minigame result"""
	if result.success:
		# Mark as complete
		PlayerData.complete_minigame(
			current_minigame_id,
			current_minigame_map,
			{
				"score": result.score,
				"time": result.time_taken,
				"stars": result.stars
			}
		)
		
		# Award keys if any
		for key_id in result.keys_found:
			PlayerData.collect_key(key_id, current_minigame_map)
		
		# Award items
		for item in result.items_awarded:
			if item.has("special") and item["special"]:
				PlayerData.add_special_item(item["id"])
			else:
				PlayerData.add_item(item.get("id", ""), item.get("amount", 1))
		
		# Award currency
		if result.currency_awarded > 0:
			PlayerData.add_currency(result.currency_awarded)
		
		# Trigger auto-save after completing minigame
		GameManager.trigger_autosave()
		
		minigame_completed.emit(current_minigame_id, result)
		print("[MinigameManager] Minigame completed: %s (Score: %d)" % [current_minigame_id, result.score])
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
	
	# Ask minigame to handle exit (it might want to show confirmation)
	if current_minigame_instance and current_minigame_instance.has_method("request_exit"):
		current_minigame_instance.request_exit()
	else:
		# Force exit
		exit_minigame(null)


func force_exit() -> void:
	"""Force exit minigame immediately"""
	exit_minigame(null)
#endregion

#region Utility
func get_current_minigame_id() -> String:
	return current_minigame_id


func get_saved_position() -> Vector2:
	return saved_position


func get_saved_map() -> String:
	return saved_map
#endregion
