extends Node2D
class_name MinigameBase
## MinigameBase - Base class for all minigames
## Developers MUST extend this class for their minigames

#region Signals (MinigameManager listens to these)
## Emit when minigame is completed successfully
signal completed(result: MinigameResult)

## Emit when minigame fails
signal failed(reason: String)

## Emit when player exits early (quit/escape)
signal exited
#endregion

#region Minigame Identity
## Unique identifier for this minigame (set in inspector or manifest)
@export var minigame_id: String = ""

## Display name shown to player
@export var display_name: String = "Minigame"

## Which map this minigame belongs to
@export var map_name: String = ""
#endregion

#region State
enum MinigameState {
	INITIALIZING,
	READY,
	PLAYING,
	PAUSED,
	COMPLETED,
	FAILED
}

var state: MinigameState = MinigameState.INITIALIZING
var _start_time: float = 0.0
var _elapsed_time: float = 0.0
var _is_paused: bool = false

## Data passed from MinigameManager
var init_data: Dictionary = {}
#endregion

#region Inventory (Minigame-specific, temporary)
## Temporary inventory for this minigame session only
## Cleared when minigame ends
var minigame_inventory: Dictionary = {}
#endregion

#region Keys Found (This session)
## Keys found during this minigame session
var keys_found_this_session: Array[String] = []
#endregion

#region Lifecycle - Override these in your minigame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Don't start automatically - wait for _initialize_minigame


func _initialize_minigame(data: Dictionary) -> void:
	"""
	Called by MinigameManager when loading the minigame.
	Override to set up your minigame.
	"""
	init_data = data
	minigame_id = data.get("minigame_id", minigame_id)
	
	state = MinigameState.READY
	print("[MinigameBase] Initialized: %s" % minigame_id)
	
	# Call custom setup
	_on_minigame_ready()


func _on_minigame_ready() -> void:
	"""
	Override this to set up your minigame.
	Called after initialization, before game starts.
	"""
	pass


func start_game() -> void:
	"""
	Call this when player is ready to start.
	Override _on_game_start for custom behavior.
	"""
	if state != MinigameState.READY:
		push_warning("[MinigameBase] Cannot start - not ready")
		return
	
	state = MinigameState.PLAYING
	_start_time = Time.get_ticks_msec() / 1000.0
	_elapsed_time = 0.0
	
	print("[MinigameBase] Game started: %s" % minigame_id)
	_on_game_start()


func _on_game_start() -> void:
	"""Override this for custom start behavior"""
	pass


func _process(delta: float) -> void:
	if state == MinigameState.PLAYING and not _is_paused:
		_elapsed_time += delta
		_on_game_update(delta)


func _on_game_update(delta: float) -> void:
	"""Override this for game loop logic"""
	pass
#endregion

#region Pause/Resume
func pause_game() -> void:
	"""Pause the minigame"""
	if state != MinigameState.PLAYING:
		return
	
	_is_paused = true
	state = MinigameState.PAUSED
	_on_game_paused()


func _on_game_paused() -> void:
	"""Override for custom pause behavior"""
	pass


func resume_game() -> void:
	"""Resume the minigame"""
	if state != MinigameState.PAUSED:
		return
	
	_is_paused = false
	state = MinigameState.PLAYING
	_on_game_resumed()


func _on_game_resumed() -> void:
	"""Override for custom resume behavior"""
	pass


func toggle_pause() -> void:
	if _is_paused:
		resume_game()
	else:
		pause_game()
#endregion

#region Complete/Fail
func complete_game(score: int = 0, custom_data: Dictionary = {}) -> void:
	"""
	Call this when player successfully completes the minigame.
	"""
	if state == MinigameState.COMPLETED or state == MinigameState.FAILED:
		return
	
	state = MinigameState.COMPLETED
	
	var result = MinigameResult.create_success(score, _elapsed_time)
	result.keys_found = keys_found_this_session
	result.custom_data = custom_data
	
	# Apply any custom result modifications
	_on_game_complete(result)
	
	print("[MinigameBase] Completed: %s (Score: %d, Time: %.2f)" % [minigame_id, score, _elapsed_time])
	completed.emit(result)


func _on_game_complete(result: MinigameResult) -> void:
	"""
	Override to modify result before sending.
	Add items, calculate stars, etc.
	"""
	pass


func fail_game(reason: String = "Game Over") -> void:
	"""
	Call this when player fails the minigame.
	"""
	if state == MinigameState.COMPLETED or state == MinigameState.FAILED:
		return
	
	state = MinigameState.FAILED
	
	_on_game_failed(reason)
	
	print("[MinigameBase] Failed: %s (%s)" % [minigame_id, reason])
	failed.emit(reason)


func _on_game_failed(reason: String) -> void:
	"""Override for custom fail behavior"""
	pass
#endregion

#region Exit Handling
func request_exit() -> void:
	"""
	Called when player tries to exit (ESC key, quit button).
	Override to show confirmation dialog.
	Default: exits immediately.
	"""
	_confirm_exit()


func _confirm_exit() -> void:
	"""Actually exit the minigame"""
	state = MinigameState.COMPLETED  # Prevent further updates
	print("[MinigameBase] Exited: %s" % minigame_id)
	exited.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC
		if state == MinigameState.PLAYING:
			request_exit()
		elif state == MinigameState.PAUSED:
			resume_game()
#endregion

#region Minigame Inventory (Temporary)
func add_minigame_item(item_id: String, amount: int = 1) -> void:
	"""Add item to minigame's temporary inventory"""
	if minigame_inventory.has(item_id):
		minigame_inventory[item_id] += amount
	else:
		minigame_inventory[item_id] = amount


func remove_minigame_item(item_id: String, amount: int = 1) -> bool:
	"""Remove item from minigame inventory"""
	if not has_minigame_item(item_id, amount):
		return false
	
	minigame_inventory[item_id] -= amount
	if minigame_inventory[item_id] <= 0:
		minigame_inventory.erase(item_id)
	return true


func has_minigame_item(item_id: String, amount: int = 1) -> bool:
	"""Check if minigame has item"""
	return minigame_inventory.get(item_id, 0) >= amount


func get_minigame_item_count(item_id: String) -> int:
	"""Get count of item in minigame inventory"""
	return minigame_inventory.get(item_id, 0)


func clear_minigame_inventory() -> void:
	"""Clear all minigame items"""
	minigame_inventory.clear()
#endregion

#region Key Collection
func collect_key(key_id: String) -> void:
	"""
	Collect a key during this minigame.
	Keys are transferred to PlayerData when minigame completes successfully.
	"""
	if key_id not in keys_found_this_session:
		keys_found_this_session.append(key_id)
		_on_key_collected(key_id)
		print("[MinigameBase] Key collected: %s" % key_id)


func _on_key_collected(key_id: String) -> void:
	"""Override for custom key collection behavior (particles, sound, etc.)"""
	pass


func has_found_key(key_id: String) -> bool:
	"""Check if key was found this session"""
	return key_id in keys_found_this_session


func get_keys_found_count() -> int:
	"""Get number of keys found this session"""
	return keys_found_this_session.size()
#endregion

#region Player Data Access (Read-only)
func get_player_data() -> Dictionary:
	"""
	Get read-only snapshot of player data.
	DO NOT modify PlayerData directly!
	"""
	return {
		"name": PlayerData.player_name,
		"total_keys": PlayerData.total_keys,
		"currency": PlayerData.currency,
		"is_replay": init_data.get("is_replay", false),
		"previous_best": init_data.get("previous_best", {})
	}


func is_replay() -> bool:
	"""Check if this is a replay (minigame already completed before)"""
	return init_data.get("is_replay", false)


func get_previous_best_score() -> int:
	"""Get previous best score (0 if never played)"""
	return init_data.get("previous_best", {}).get("score", 0)
#endregion

#region Timer Helpers
func get_elapsed_time() -> float:
	"""Get time since game started (seconds)"""
	return _elapsed_time


func get_elapsed_time_formatted() -> String:
	"""Get elapsed time as MM:SS"""
	var minutes = int(_elapsed_time / 60)
	var seconds = int(fmod(_elapsed_time, 60))
	return "%02d:%02d" % [minutes, seconds]


func get_elapsed_time_precise() -> String:
	"""Get elapsed time as MM:SS.MS"""
	var minutes = int(_elapsed_time / 60)
	var seconds = int(fmod(_elapsed_time, 60))
	var ms = int(fmod(_elapsed_time * 100, 100))
	return "%02d:%02d.%02d" % [minutes, seconds, ms]
#endregion

#region Utility
func is_playing() -> bool:
	return state == MinigameState.PLAYING


func is_paused() -> bool:
	return state == MinigameState.PAUSED


func is_finished() -> bool:
	return state == MinigameState.COMPLETED or state == MinigameState.FAILED
#endregion
