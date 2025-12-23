extends Node2D
## Bhaktapur - Main starting map
## Attach to root node of bhaktapur.tscn

#region Configuration
@export var map_id: String = "bhaktapur"
@export var default_spawn_position: Vector2 = Vector2(200, 200)
@export_file("*.tscn") var player_scene_path: String = "res://Sceans/MainCharacter/main_character.tscn"
#endregion

#region Spawn Points - Define where player spawns from different locations
var spawn_points: Dictionary = {
	"default": Vector2(200, 200),
	"from_kathmandu": Vector2(100, 300),
	"from_minigame": Vector2(0, 0),  # Will use saved position
}
#endregion

#region Map State - What changes when minigames are completed
## Format: {"minigame_id": {"show": [node_paths], "hide": [node_paths]}}
var completion_effects: Dictionary = {
	# Example:
	# "maze_game": {
	#     "show": ["CompletedMazeDecoration"],
	#     "hide": ["MazeEntrance/BlockedSign"],
	# },
}
#endregion

#region Node References
var current_player: CharacterBody2D = null
@onready var pause_menu: Control = $UI/PauseMenu if has_node("UI/PauseMenu") else null
#endregion

func _ready() -> void:
	# Register with GameManager
	if GameManager:
		GameManager.register_map(self)
		GameManager.current_map = map_id
	
	# Determine spawn position
	var spawn_pos = _determine_spawn_position()
	
	# Spawn or find player
	_setup_player(spawn_pos)
	
	# Apply visual changes based on completed minigames
	_apply_completion_effects()
	
	# Connect to PlayerData for live updates
	if PlayerData:
		if not PlayerData.minigame_completed.is_connected(_on_minigame_completed):
			PlayerData.minigame_completed.connect(_on_minigame_completed)
	
	print("[Bhaktapur] Map ready. Player at: %s" % spawn_pos)


func _determine_spawn_position() -> Vector2:
	"""Figure out where to spawn the player"""
	
	# 1. Check if returning from minigame (MinigameManager has saved position)
	if MinigameManager and MinigameManager.saved_position != Vector2.ZERO:
		var pos = MinigameManager.saved_position
		MinigameManager.saved_position = Vector2.ZERO  # Clear it
		print("[Bhaktapur] Using minigame return position: %s" % pos)
		return pos
	
	# 2. Check if GameManager has a pending position
	if GameManager:
		var pending_pos = GameManager.get_spawn_position()
		if pending_pos != Vector2.ZERO:
			print("[Bhaktapur] Using GameManager pending position: %s" % pending_pos)
			return pending_pos
		
		# Check for named spawn point
		var spawn_name = GameManager.get_spawn_point_name()
		if not spawn_name.is_empty() and spawn_points.has(spawn_name):
			print("[Bhaktapur] Using spawn point: %s" % spawn_name)
			return spawn_points[spawn_name]
	
	# 3. Check if we have a saved position for this map
	if PlayerData:
		var saved_pos = PlayerData.get_map_position(map_id)
		if saved_pos != Vector2.ZERO:
			print("[Bhaktapur] Using saved position: %s" % saved_pos)
			return saved_pos
	
	# 4. Use default spawn
	print("[Bhaktapur] Using default spawn position")
	return default_spawn_position


func _setup_player(spawn_pos: Vector2) -> void:
	"""Find existing player or spawn new one"""
	
	# First, check if player already exists in scene
	current_player = _find_existing_player()
	
	if current_player:
		# Player exists, just move them
		current_player.global_position = spawn_pos
		print("[Bhaktapur] Moved existing player to: %s" % spawn_pos)
	else:
		# Need to spawn player
		_spawn_player(spawn_pos)
	
	# Make sure player is in group and registered
	if current_player:
		if not current_player.is_in_group("player"):
			current_player.add_to_group("player")
		
		if GameManager:
			GameManager.register_player(current_player)


func _find_existing_player() -> CharacterBody2D:
	"""Find player if already in scene"""
	# Check by node name
	var player = get_node_or_null("MainCharacter")
	if player:
		return player
	
	player = get_node_or_null("Player")
	if player:
		return player
	
	# Check by group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	
	return null


func _spawn_player(position: Vector2) -> void:
	"""Spawn a new player instance"""
	var player_scene = load(player_scene_path)
	if not player_scene:
		push_error("[Bhaktapur] Could not load player scene: %s" % player_scene_path)
		return
	
	current_player = player_scene.instantiate()
	current_player.global_position = position
	add_child(current_player)
	
	print("[Bhaktapur] Spawned player at: %s" % position)


#region Map State / Visual Changes
func _apply_completion_effects() -> void:
	"""Apply visual changes based on completed minigames"""
	if not PlayerData:
		return
	
	var completed = PlayerData.get_completed_minigames_for_map(map_id)
	
	for minigame_id in completed:
		_apply_single_effect(minigame_id)


func _apply_single_effect(minigame_id: String) -> void:
	"""Apply effect for a single completed minigame"""
	if not completion_effects.has(minigame_id):
		return
	
	var effects = completion_effects[minigame_id]
	
	# Show nodes
	for node_path in effects.get("show", []):
		var node = get_node_or_null(node_path)
		if node:
			node.show()
	
	# Hide nodes
	for node_path in effects.get("hide", []):
		var node = get_node_or_null(node_path)
		if node:
			node.hide()
	
	# Enable nodes
	for node_path in effects.get("enable", []):
		var node = get_node_or_null(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Disable nodes
	for node_path in effects.get("disable", []):
		var node = get_node_or_null(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED


func _on_minigame_completed(minigame_id: String, completed_map: String) -> void:
	"""Called when any minigame is completed"""
	if completed_map == map_id:
		_apply_single_effect(minigame_id)
#endregion

#region Player Position Saving
func save_player_position() -> void:
	"""Save current player position"""
	if current_player and PlayerData:
		PlayerData.save_map_position(map_id, current_player.global_position)
		print("[Bhaktapur] Saved position: %s" % current_player.global_position)


func get_player_position() -> Vector2:
	"""Get current player position"""
	if current_player:
		return current_player.global_position
	return Vector2.ZERO
#endregion

#region Map Transitions
func go_to_map(target_map: String, spawn_point: String = "") -> void:
	"""Transition to another map"""
	# Save current position before leaving
	save_player_position()
	
	# Trigger autosave
	if GameManager:
		GameManager.trigger_autosave()
	
	# Change map
	if GameManager:
		GameManager.change_map(target_map, Vector2.ZERO, spawn_point)
	else:
		var path = "res://Sceans/Core/Maps/%s.tscn" % target_map
		get_tree().change_scene_to_file(path)
#endregion

#region Utility
func get_player() -> CharacterBody2D:
	return current_player


func teleport_player(position: Vector2) -> void:
	"""Teleport player to position"""
	if current_player:
		current_player.global_position = position
#endregion
