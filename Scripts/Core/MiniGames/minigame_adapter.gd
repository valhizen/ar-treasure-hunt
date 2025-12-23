extends Node
## MinigameAdapter - Bridge between minigames and the game system
## UPDATED: Now submits scores to server automatically
## 
## Attach this as a CHILD of your minigame root node.
## Call complete_minigame() when player wins/finishes.

class_name MinigameAdapter

#region Signals
signal minigame_started
signal minigame_completed_signal(score: int)
signal minigame_failed_signal(reason: String)
signal score_submitted(success: bool)
#endregion

#region Configuration
## The unique ID of this minigame (must match server expectations)
@export var minigame_id: String = ""

## Map this minigame belongs to
@export var map_name: String = "bhaktapur"

## Allow ESC to exit minigame
@export var allow_escape_exit: bool = true

## Automatically submit score to server on completion
@export var auto_submit_score: bool = true

## Stars thresholds [1-star, 2-star, 3-star]
@export var star_thresholds: Array[int] = [1000, 3000, 5000]

## Time limit in seconds (0 = no limit)
@export var time_limit: float = 0.0
#endregion

#region State
var start_time: float = 0.0
var current_score: int = 0
var keys_found: Array = []
var is_completed: bool = false
var is_failed: bool = false
#endregion

func _ready() -> void:
	# Auto-detect minigame_id from scene name if not set
	if minigame_id.is_empty():
		minigame_id = get_parent().name.to_snake_case()
	
	start_time = Time.get_unix_time_from_system()
	is_completed = false
	is_failed = false
	current_score = 0
	keys_found.clear()
	
	# Notify game we're in minigame
	if GameManager:
		GameManager.set_minigame_state(true)
	
	minigame_started.emit()
	print("[MinigameAdapter] Started: %s" % minigame_id)


func _input(event: InputEvent) -> void:
	if allow_escape_exit and event.is_action_pressed("ui_cancel"):
		exit_minigame()
		get_viewport().set_input_as_handled()


#region Score Methods
func add_score(points: int) -> void:
	"""Add points to current score"""
	current_score += points
	print("[MinigameAdapter] Score: %d (+%d)" % [current_score, points])


func set_score(points: int) -> void:
	"""Set score directly"""
	current_score = points


func get_score() -> int:
	"""Get current score"""
	return current_score
#endregion

#region Key Collection
func collect_key(key_id: String) -> void:
	"""Register a key collection"""
	if key_id not in keys_found:
		keys_found.append(key_id)
		print("[MinigameAdapter] Key collected: %s (Total: %d)" % [key_id, keys_found.size()])


func get_keys_found() -> Array:
	"""Get all keys found in this session"""
	return keys_found
#endregion

#region Time Tracking
func get_elapsed_time() -> float:
	"""Get time since minigame started"""
	return Time.get_unix_time_from_system() - start_time


func get_remaining_time() -> float:
	"""Get remaining time (if time limit is set)"""
	if time_limit <= 0:
		return -1.0
	return max(0.0, time_limit - get_elapsed_time())


func is_time_up() -> bool:
	"""Check if time limit exceeded"""
	return time_limit > 0 and get_elapsed_time() >= time_limit
#endregion

#region Star Calculation
func calculate_stars(score: int = -1) -> int:
	"""Calculate stars based on score"""
	if score < 0:
		score = current_score
	
	if score >= star_thresholds[2]:
		return 3
	elif score >= star_thresholds[1]:
		return 2
	elif score >= star_thresholds[0]:
		return 1
	else:
		return 0
#endregion

#region Completion Methods
func complete_minigame(final_score: int = -1) -> void:
	"""
	Call this when player completes the minigame successfully.
	This will:
	1. Save to PlayerData (local)
	2. Submit to server (online)
	3. Return to map
	"""
	if is_completed or is_failed:
		return
	
	is_completed = true
	
	# Use provided score or current score
	if final_score >= 0:
		current_score = final_score
	
	var time_taken = get_elapsed_time()
	var stars = calculate_stars()
	
	print("[MinigameAdapter] ═══════════════════════════════════════")
	print("[MinigameAdapter] MINIGAME COMPLETED!")
	print("[MinigameAdapter] ID: %s" % minigame_id)
	print("[MinigameAdapter] Score: %d" % current_score)
	print("[MinigameAdapter] Stars: %d" % stars)
	print("[MinigameAdapter] Time: %.1fs" % time_taken)
	print("[MinigameAdapter] Keys: %d" % keys_found.size())
	print("[MinigameAdapter] ═══════════════════════════════════════")
	
	# Build result data
	var result_data = {
		"score": current_score,
		"time": time_taken,
		"time_taken": time_taken,
		"stars": stars,
		"success": true,
		"keys_found": keys_found.size()
	}
	
	# ═══════════════════════════════════════════════════════════════════
	# STEP 1: Save to PlayerData (LOCAL)
	# ═══════════════════════════════════════════════════════════════════
	if PlayerData:
		PlayerData.complete_minigame(minigame_id, map_name, result_data)
		
		# Also register collected keys
		for key_id in keys_found:
			PlayerData.collect_key(key_id, map_name)
	
	# ═══════════════════════════════════════════════════════════════════
	# STEP 2: Submit to Server (ONLINE)
	# ═══════════════════════════════════════════════════════════════════
	if auto_submit_score:
		_submit_score_to_server(current_score, stars, time_taken)
	
	# Emit signal
	minigame_completed_signal.emit(current_score)
	
	# ═══════════════════════════════════════════════════════════════════
	# STEP 3: Return to Map
	# ═══════════════════════════════════════════════════════════════════
	_exit_to_map(result_data)


func fail_minigame(reason: String = "Failed") -> void:
	"""Call this when player fails the minigame"""
	if is_completed or is_failed:
		return
	
	is_failed = true
	
	print("[MinigameAdapter] MINIGAME FAILED: %s" % reason)
	
	var result_data = {
		"score": current_score,
		"time": get_elapsed_time(),
		"stars": 0,
		"success": false,
		"fail_reason": reason
	}
	
	minigame_failed_signal.emit(reason)
	
	# Still exit to map
	_exit_to_map(result_data)


func exit_minigame() -> void:
	"""Exit minigame without completing (ESC pressed)"""
	if is_completed or is_failed:
		return
	
	print("[MinigameAdapter] Minigame exited early")
	
	var result_data = {
		"score": current_score,
		"time": get_elapsed_time(),
		"stars": 0,
		"success": false,
		"exited_early": true
	}
	
	_exit_to_map(result_data)
#endregion

#region Server Communication
func _submit_score_to_server(score: int, stars: int, time_taken: float) -> void:
	"""Submit score to server via ScoreManager"""
	if not AuthManager or not AuthManager.is_logged_in:
		print("[MinigameAdapter] Not logged in, score saved locally only")
		score_submitted.emit(false)
		return
	
	# Get event code if active
	var event_code = ""
	if AuthManager.is_event_active():
		event_code = AuthManager.get_event_code()
	
	# Extra data for server
	var extra_data = {
		"stars": stars,
		"time_taken": time_taken,
		"map": map_name,
		"keys_found": keys_found.size()
	}
	
	# Submit via ScoreManager
	if ScoreManager:
		var response = await ScoreManager.submit_score(minigame_id, score, extra_data)
		
		if response.success:
			print("[MinigameAdapter] Score submitted to server! Rank: #%s" % response.data.get("rank", "?"))
			score_submitted.emit(true)
		else:
			print("[MinigameAdapter] Score queued for later (offline)")
			score_submitted.emit(false)
	else:
		print("[MinigameAdapter] ScoreManager not available")
		score_submitted.emit(false)
#endregion

#region Exit Handling
func _exit_to_map(result_data: Dictionary) -> void:
	"""Return to the map"""
	# Create result object for MinigameManager
	var result = null
	
	if MinigameManager:
		# Use MinigameManager's result class if available
		if MinigameManager.has_method("create_result"):
			result = MinigameManager.create_result(minigame_id, result_data)
		
		# Notify game we're leaving minigame
		GameManager.set_minigame_state(false) if GameManager else null
		
		# Exit through MinigameManager (returns to map at saved position)
		MinigameManager.exit_minigame(result)
	else:
		# Fallback: just change scene
		print("[MinigameAdapter] MinigameManager not available, using fallback exit")
		GameManager.set_minigame_state(false) if GameManager else null
		
		var map_path = "res://Sceans/Core/Maps/%s.tscn" % map_name
		get_tree().change_scene_to_file(map_path)
#endregion

#region Utility
func get_result_summary() -> Dictionary:
	"""Get summary of current minigame state"""
	return {
		"minigame_id": minigame_id,
		"map_name": map_name,
		"score": current_score,
		"stars": calculate_stars(),
		"time_elapsed": get_elapsed_time(),
		"keys_found": keys_found.size(),
		"is_completed": is_completed,
		"is_failed": is_failed
	}
#endregion
