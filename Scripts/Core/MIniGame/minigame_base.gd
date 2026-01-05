extends Node2D
class_name MinigameBase
## MinigameBase - Base class for all minigames
## Extend this class and override the virtual methods

#region Signals
signal completed(result: MinigameResult)
signal failed(reason: String)
signal exited
signal score_changed(new_score: int)
signal time_updated(time_remaining: float)
#endregion

#region Configuration
@export_category("Minigame Settings")
@export var minigame_id: String = ""
@export var display_name: String = ""
@export var time_limit: float = 0.0  # 0 = no limit
@export var max_score: int = 1000

@export_category("Star Thresholds (percentage)")
@export var star_1_percent: int = 30
@export var star_2_percent: int = 60
@export var star_3_percent: int = 90

@export_category("Countdown")
@export var use_countdown: bool = true
@export var countdown_time: float = 3.0
#endregion

#region State
enum GameState { INITIALIZING, READY, COUNTDOWN, PLAYING, PAUSED, COMPLETED, FAILED, EXITING }

var current_state: GameState = GameState.INITIALIZING
var current_score: int = 0
var time_elapsed: float = 0.0
var time_remaining: float = 0.0
var is_replay: bool = false
var previous_best: Dictionary = {}
var player_name: String = ""
var player_id: String = ""
var keys_found: Array[String] = []
var game_data: Dictionary = {}

var _countdown_timer: float = 0.0
var _initialized_by_manager: bool = false
#endregion


#region Virtual Methods - OVERRIDE THESE IN YOUR MINIGAME
func _setup_game() -> void:
	"""Override: Called after initialization to setup your game"""
	pass


func _start_game() -> void:
	"""Override: Called when countdown ends and gameplay begins"""
	pass


func _update_game(delta: float) -> void:
	"""Override: Called every frame during PLAYING state"""
	pass


func _on_game_paused() -> void:
	"""Override: Called when game is paused"""
	pass


func _on_game_resumed() -> void:
	"""Override: Called when game is resumed"""
	pass


func _on_time_up() -> void:
	"""Override: Called when time runs out"""
	complete_game()


func _cleanup_game() -> void:
	"""Override: Cleanup before exiting"""
	pass


func _calculate_final_score() -> int:
	"""Override: Calculate final score (default returns current_score)"""
	return current_score


func _calculate_rewards(_score: int, stars: int) -> Dictionary:
	"""Override: Calculate rewards based on performance"""
	return {
		"currency": 10 * (stars + 1),
		"items": []
	}
#endregion


#region Lifecycle
func _ready() -> void:
	add_to_group("minigame")
	
	# Auto-initialize if not started by MinigameManager
	# This allows testing minigames directly
	call_deferred("_check_auto_init")


func _check_auto_init() -> void:
	"""Auto-initialize if running standalone (not through MinigameManager)"""
	if not _initialized_by_manager:
		print("[MinigameBase] Running standalone - auto initializing")
		_initialize_minigame({
			"minigame_id": minigame_id,
			"player_name": "Player",
			"player_id": "",
			"is_replay": false,
			"previous_best": {}
		})


func _initialize_minigame(init_data: Dictionary) -> void:
	"""Called by MinigameManager when minigame loads"""
	_initialized_by_manager = true
	
	minigame_id = init_data.get("minigame_id", minigame_id)
	player_name = init_data.get("player_name", "Player")
	player_id = init_data.get("player_id", "")
	is_replay = init_data.get("is_replay", false)
	previous_best = init_data.get("previous_best", {})
	
	# Reset state
	current_score = 0
	time_elapsed = 0.0
	keys_found.clear()
	game_data.clear()
	
	if time_limit > 0:
		time_remaining = time_limit
	
	print("[MinigameBase] Initialized: %s" % minigame_id)
	
	current_state = GameState.READY
	
	# Call subclass setup
	_setup_game()
	
	# Start game (with or without countdown)
	if use_countdown and countdown_time > 0:
		_start_countdown()
	else:
		_begin_playing()


func _process(delta: float) -> void:
	match current_state:
		GameState.COUNTDOWN:
			_process_countdown(delta)
		GameState.PLAYING:
			_process_playing(delta)


func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	
	if _countdown_timer <= 0:
		_begin_playing()


func _process_playing(delta: float) -> void:
	time_elapsed += delta
	
	# Time limit handling
	if time_limit > 0:
		time_remaining -= delta
		time_updated.emit(time_remaining)
		
		if time_remaining <= 0:
			time_remaining = 0
			_on_time_up()
			return
	
	# Call subclass update
	_update_game(delta)
#endregion


#region Game Control
func _start_countdown() -> void:
	_countdown_timer = countdown_time
	current_state = GameState.COUNTDOWN
	print("[MinigameBase] Countdown started: %.1f seconds" % countdown_time)


func _begin_playing() -> void:
	current_state = GameState.PLAYING
	print("[MinigameBase] Game started!")
	_start_game()


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		_on_game_paused()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		_on_game_resumed()


func complete_game() -> void:
	"""Call this when minigame is completed successfully"""
	if current_state == GameState.COMPLETED or current_state == GameState.FAILED:
		return
	
	current_state = GameState.COMPLETED
	
	var final_score = _calculate_final_score()
	var stars = _calculate_stars(final_score)
	var rewards = _calculate_rewards(final_score, stars)
	
	var result = MinigameResult.new()
	result.minigame_id = minigame_id
	result.success = true
	result.score = final_score
	result.time_taken = time_elapsed
	result.stars = stars
	result.keys_found.assign(keys_found)
	result.currency_awarded = rewards.get("currency", 0)
	result.items_awarded = rewards.get("items", [])
	result.custom_data = game_data
	
	print("[MinigameBase] Completed! Score: %d, Stars: %d" % [final_score, stars])
	
	completed.emit(result)
	
	# Auto-exit after delay
	_auto_exit_after_delay(result)


func fail_game(reason: String = "Game Over") -> void:
	"""Call this when minigame is failed"""
	if current_state == GameState.COMPLETED or current_state == GameState.FAILED:
		return
	
	current_state = GameState.FAILED
	
	var result = MinigameResult.new()
	result.minigame_id = minigame_id
	result.success = false
	result.score = current_score
	result.time_taken = time_elapsed
	result.failure_reason = reason
	
	print("[MinigameBase] Failed: %s" % reason)
	
	failed.emit(reason)
	
	_auto_exit_after_delay(result)


func request_exit() -> void:
	"""Called when player wants to exit (ESC key, etc.)"""
	if current_state == GameState.EXITING:
		return
	
	current_state = GameState.EXITING
	_cleanup_game()
	exited.emit()
	
	_exit_to_map()


func _auto_exit_after_delay(result: MinigameResult) -> void:
	"""Wait then exit to map"""
	var tree = get_tree()
	if tree:
		await tree.create_timer(2.5).timeout
	
	var manager = get_node_or_null("/root/MinigameManager")
	if manager:
		manager.exit_minigame(result)
	else:
		print("[MinigameBase] No MinigameManager - staying in scene")


func _exit_to_map() -> void:
	"""Exit back to the map"""
	var manager = get_node_or_null("/root/MinigameManager")
	if manager:
		manager.exit_minigame(null)
#endregion


#region Score Management
func add_score(points: int) -> void:
	"""Add points to current score"""
	current_score += points
	score_changed.emit(current_score)


func set_score(points: int) -> void:
	"""Set score to specific value"""
	current_score = points
	score_changed.emit(current_score)


func collect_key(key_id: String) -> void:
	"""Collect a key during the minigame"""
	if key_id not in keys_found:
		keys_found.append(key_id)
		print("[MinigameBase] Key collected: %s" % key_id)


func _calculate_stars(score: int) -> int:
	"""Calculate stars based on score percentage"""
	var percentage = float(score) / float(max_score) * 100.0 if max_score > 0 else 0.0
	
	if percentage >= star_3_percent:
		return 3
	elif percentage >= star_2_percent:
		return 2
	elif percentage >= star_1_percent:
		return 1
	return 0
#endregion


#region State Checks
func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_paused() -> bool:
	return current_state == GameState.PAUSED


func is_active() -> bool:
	return current_state in [GameState.PLAYING, GameState.COUNTDOWN]
#endregion


#region Input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING:
			# You can either pause or exit - adjust as needed
			request_exit()
#endregion
