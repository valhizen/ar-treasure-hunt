extends Node2D
class_name MapBase
## MapBase - Base class for all game maps
## Handles player spawning, map state, and visual changes based on progress

#region Configuration
## Unique identifier for this map
@export var map_id: String = ""

## Default spawn position if none specified
@export var default_spawn_position: Vector2 = Vector2(100, 100)

## Named spawn points (e.g., "from_kathmandu", "from_minigame")
@export var spawn_points: Dictionary = {}  # {"name": Vector2}

## Player scene to instantiate
@export var player_scene: PackedScene = null
#endregion

#region Map State Configuration
## Define what changes when minigames are completed
## Format: {"minigame_id": {"show": ["node_path"], "hide": ["node_path"], ...}}
@export var completion_effects: Dictionary = {}
#endregion

#region Node References
@onready var player_spawn: Marker2D = $PlayerSpawn if has_node("PlayerSpawn") else null
@onready var player_container: Node2D = $PlayerContainer if has_node("PlayerContainer") else null
#endregion

#region State
var current_player: CharacterBody2D = null
var is_initialized: bool = false
#endregion

#region Lifecycle
func _ready() -> void:
	# Register with GameManager
	GameManager.register_map(self)
	
	# Determine spawn position
	var spawn_pos = _determine_spawn_position()
	
	# Spawn player
	_spawn_player(spawn_pos)
	
	# Apply map state based on completed minigames
	_apply_completion_effects()
	
	# Connect to PlayerData signals for live updates
	PlayerData.minigame_completed.connect(_on_minigame_completed)
	
	is_initialized = true
	print("[MapBase] Map initialized: %s" % map_id)


func _determine_spawn_position() -> Vector2:
	"""Determine where to spawn the player"""
	# 1. Check if GameManager has a pending position (returning from minigame)
	var pending_pos = GameManager.get_spawn_position()
	if pending_pos != Vector2.ZERO:
		return pending_pos
	
	# 2. Check if there's a named spawn point requested
	var spawn_point_name = GameManager.get_spawn_point_name()
	if not spawn_point_name.is_empty() and spawn_points.has(spawn_point_name):
		return spawn_points[spawn_point_name]
	
	# 3. Check if we have a saved position for this map
	var saved_pos = PlayerData.get_map_position(map_id)
	if saved_pos != Vector2.ZERO:
		return saved_pos
	
	# 4. Use the spawn marker if exists
	if player_spawn:
		return player_spawn.global_position
	
	# 5. Default position
	return default_spawn_position
#endregion

#region Player Management
func _spawn_player(position: Vector2) -> void:
	"""Spawn the player at the given position"""
	if player_scene == null:
		player_scene = _get_default_player_scene()
	
	if player_scene == null:
		push_error("[MapBase] No player scene set!")
		return
	
	current_player = player_scene.instantiate() as CharacterBody2D
	if current_player == null:
		push_error("[MapBase] Player scene is not a CharacterBody2D!")
		return
	
	current_player.global_position = position
	
	# Add to container or directly to map
	if player_container:
		player_container.add_child(current_player)
	else:
		add_child(current_player)
	
	# Register with GameManager
	GameManager.register_player(current_player)
	
	# Add to player group
	current_player.add_to_group("player")
	
	print("[MapBase] Player spawned at %s" % position)


func _get_default_player_scene() -> PackedScene:
	"""Try to load the default player scene"""
	var possible_paths = [
		"res://Sceans/MainCharacter/main_character.tscn",
		"res://Scenes/MainCharacter/main_character.tscn",
		"res://Scenes/Player/player.tscn"
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			return load(path)
	
	return null


func get_player() -> CharacterBody2D:
	"""Get reference to current player"""
	return current_player


func teleport_player(position: Vector2) -> void:
	"""Teleport player to a position"""
	if current_player:
		current_player.global_position = position
		PlayerData.save_map_position(map_id, position)
#endregion

#region Map State / Visual Changes
func _apply_completion_effects() -> void:
	"""Apply visual changes based on completed minigames"""
	var completed = PlayerData.get_completed_minigames_for_map(map_id)
	
	for minigame_id in completed:
		_apply_minigame_effect(minigame_id)


func _apply_minigame_effect(minigame_id: String) -> void:
	"""Apply the visual effect for a completed minigame"""
	if not completion_effects.has(minigame_id):
		return
	
	var effects = completion_effects[minigame_id]
	
	# Show nodes
	var show_nodes: Array = effects.get("show", [])
	for node_path in show_nodes:
		var node = get_node_or_null(node_path)
		if node:
			node.show()
	
	# Hide nodes
	var hide_nodes: Array = effects.get("hide", [])
	for node_path in hide_nodes:
		var node = get_node_or_null(node_path)
		if node:
			node.hide()
	
	# Enable/Disable nodes
	var enable_nodes: Array = effects.get("enable", [])
	for node_path in enable_nodes:
		var node = get_node_or_null(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT
			if node is CollisionShape2D:
				node.disabled = false
	
	var disable_nodes: Array = effects.get("disable", [])
	for node_path in disable_nodes:
		var node = get_node_or_null(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CollisionShape2D:
				node.disabled = true
	
	# Swap textures
	var texture_swaps: Dictionary = effects.get("textures", {})
	for node_path in texture_swaps:
		var node = get_node_or_null(node_path)
		if node and node is Sprite2D:
			var texture_path = texture_swaps[node_path]
			var texture = load(texture_path)
			if texture:
				node.texture = texture
	
	# Call custom functions
	var custom_calls: Array = effects.get("call", [])
	for method_name in custom_calls:
		if has_method(method_name):
			call(method_name)


func _on_minigame_completed(minigame_id: String, map_name: String) -> void:
	"""Called when a minigame is completed (live update)"""
	if map_name == map_id:
		_apply_minigame_effect(minigame_id)
#endregion

#region Map Transitions
func transition_to_map(target_map: String, spawn_point: String = "") -> void:
	"""Transition to another map"""
	if not PlayerData.is_map_unlocked(target_map):
		print("[MapBase] Cannot transition - map locked: %s" % target_map)
		# You might want to show a message to the player here
		return
	
	# Save current position before leaving
	if current_player:
		PlayerData.save_map_position(map_id, current_player.global_position)
	
	# Trigger autosave
	GameManager.trigger_autosave()
	
	# Change map
	GameManager.change_map(target_map, Vector2.ZERO, spawn_point)
#endregion

#region Spawn Point Registration
func register_spawn_point(point_name: String, position: Vector2) -> void:
	"""Register a named spawn point"""
	spawn_points[point_name] = position


func get_spawn_point(point_name: String) -> Vector2:
	"""Get a spawn point by name"""
	return spawn_points.get(point_name, default_spawn_position)
#endregion

#region Save Position (called before map changes/minigames)
func save_current_position() -> void:
	"""Save player's current position"""
	if current_player:
		PlayerData.save_map_position(map_id, current_player.global_position)
#endregion
