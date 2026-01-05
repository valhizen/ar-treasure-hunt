extends Node
class_name MinigameAdapter
## MinigameAdapter - Quick way to connect existing minigames to the system
## Add this as a child node to any minigame scene that doesn't extend MinigameBase

## HOW TO USE:
## 1. Add this node as a child of your minigame's root node
## 2. Connect your game's completion to call adapter.complete_with_score(score)
## 3. Connect your game's failure to call adapter.fail_with_reason(reason)
## 4. That's it! The adapter handles everything else.

#region Signals (same as MinigameBase)
signal completed(result: MinigameResult)
signal failed(reason: String)
signal exited
#endregion

#region Configuration
@export var minigame_id: String = ""
@export var max_score: int = 1000
@export var star_1_threshold: int = 30
@export var star_2_threshold: int = 60
@export var star_3_threshold: int = 90
#endregion

#region State
var time_elapsed: float = 0.0
var is_active: bool = false
var init_data: Dictionary = {}
var collected_keys: Array[String] = []
var custom_data: Dictionary = {}
#endregion


func _ready() -> void:
	# Auto-start when scene loads
	call_deferred("_auto_initialize")


func _auto_initialize() -> void:
	"""Automatically initialize if MinigameManager started us"""
	var manager = get_node_or_null("/root/MinigameManager")
	if manager and manager.is_in_minigame:
		# We were loaded by the manager, connect ourselves
		_initialize_minigame(manager._get_minigame_init_data())
		
		# Connect our signals to the manager
		if not completed.is_connected(manager._on_minigame_completed):
			completed.connect(manager._on_minigame_completed)
		if not failed.is_connected(manager._on_minigame_failed):
			failed.connect(manager._on_minigame_failed)
		if not exited.is_connected(manager._on_minigame_exited):
			exited.connect(manager._on_minigame_exited)


func _initialize_minigame(data: Dictionary) -> void:
	"""Called by MinigameManager"""
	init_data = data
	minigame_id = data.get("minigame_id", minigame_id)
	is_active = true
	time_elapsed = 0.0
	print("[MinigameAdapter] Initialized: %s" % minigame_id)


func _process(delta: float) -> void:
	if is_active:
		time_elapsed += delta


#region Public API - Call these from your game
func complete_with_score(score: int, extra_data: Dictionary = {}) -> void:
	"""Call this when your minigame completes successfully"""
	if not is_active:
		return
	
	is_active = false
	var stars = _calculate_stars(score)
	
	var result = MinigameResult.new()
	result.minigame_id = minigame_id
	result.success = true
	result.score = score
	result.time_taken = time_elapsed
	result.stars = stars
	result.keys_found.assign(collected_keys)
	result.custom_data = extra_data
	result.custom_data.merge(custom_data)
	
	# Calculate currency reward
	result.currency_awarded = _calculate_currency(score, stars)
	
	print("[MinigameAdapter] Completed! Score: %d, Stars: %d" % [score, stars])
	completed.emit(result)


func fail_with_reason(reason: String = "Game Over") -> void:
	"""Call this when your minigame fails"""
	if not is_active:
		return
	
	is_active = false
	
	var result = MinigameResult.new()
	result.minigame_id = minigame_id
	result.success = false
	result.failure_reason = reason
	result.time_taken = time_elapsed
	
	print("[MinigameAdapter] Failed: %s" % reason)
	failed.emit(reason)


func exit_early() -> void:
	"""Call this when player exits without completing"""
	if not is_active:
		return
	
	is_active = false
	print("[MinigameAdapter] Exited early")
	exited.emit()


func collect_key(key_id: String) -> void:
	"""Call this when player collects a key in your minigame"""
	if key_id not in collected_keys:
		collected_keys.append(key_id)
		print("[MinigameAdapter] Key collected: %s" % key_id)


func set_custom_data(key: String, value) -> void:
	"""Store custom data that will be included in the result"""
	custom_data[key] = value


func get_player_name() -> String:
	"""Get the player's name"""
	return init_data.get("player_name", "Player")


func is_replay() -> bool:
	"""Check if this is a replay of a completed minigame"""
	return init_data.get("is_replay", false)


func get_previous_best() -> Dictionary:
	"""Get previous best score data"""
	return init_data.get("previous_best", {})
#endregion


#region Internal
func _calculate_stars(score: int) -> int:
	var percentage = float(score) / float(max_score) * 100.0 if max_score > 0 else 0.0
	
	if percentage >= star_3_threshold:
		return 3
	elif percentage >= star_2_threshold:
		return 2
	elif percentage >= star_1_threshold:
		return 1
	return 0


func _calculate_currency(score: int, stars: int) -> int:
	return 10 + (stars * 15)
#endregion
