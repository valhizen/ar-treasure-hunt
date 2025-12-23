extends MinigameBase
## ExampleMinigame - Template for minigame developers
## COPY THIS FILE and modify for your minigame
## 
## HOW TO USE:
## 1. Copy this file to your minigame folder
## 2. Rename class and file to match your minigame
## 3. Implement the _on_* methods
## 4. Create your scene with this script attached to root
## 5. Add manifest.json with your minigame info

#region Configuration
## How many keys can be found in this minigame
@export var total_keys: int = 1

## Time limit (0 = no limit)
@export var time_limit: float = 0.0

## Score thresholds for stars [1-star, 2-star, 3-star]
@export var star_thresholds: Array[int] = [100, 300, 500]
#endregion

#region Your Variables
# Add your minigame-specific variables here
var score: int = 0
var keys_collected: int = 0
# var player_health: int = 100
# var enemies_defeated: int = 0
# etc.
#endregion

#region Lifecycle Overrides
func _on_minigame_ready() -> void:
	"""
	Called when minigame is initialized but before it starts.
	Set up your scene here.
	"""
	# Example: Show a "Press SPACE to start" screen
	# $UI/StartScreen.show()
	
	# Or start immediately:
	start_game()


func _on_game_start() -> void:
	"""
	Called when the game actually starts.
	Start spawning enemies, enable player control, etc.
	"""
	# Example:
	# $Player.enable_control()
	# $EnemySpawner.start()
	# $Timer.start()
	pass


func _on_game_update(delta: float) -> void:
	"""
	Called every frame while game is running.
	Your main game loop logic goes here.
	"""
	# Example: Check time limit
	if time_limit > 0 and get_elapsed_time() >= time_limit:
		_on_time_up()
	
	# Example: Update UI
	# $UI/ScoreLabel.text = "Score: %d" % score
	# $UI/TimeLabel.text = get_elapsed_time_formatted()


func _on_game_paused() -> void:
	"""Called when game is paused"""
	# Example: Show pause menu
	# $UI/PauseMenu.show()
	pass


func _on_game_resumed() -> void:
	"""Called when game is resumed"""
	# Example: Hide pause menu
	# $UI/PauseMenu.hide()
	pass


func _on_game_complete(result: MinigameResult) -> void:
	"""
	Called just before completion signal is emitted.
	Modify the result here (add items, calculate stars, etc.)
	"""
	# Calculate stars based on score
	result.calculate_stars_by_score(star_thresholds)
	
	# Example: Award bonus item for 3 stars
	if result.stars >= 3:
		result.with_item("gold_trophy", 1, true)  # true = special item
	
	# Example: Award currency based on score
	result.with_currency(score / 10)


func _on_game_failed(reason: String) -> void:
	"""Called when game fails"""
	# Example: Show game over screen
	# $UI/GameOverScreen.show()
	# $UI/GameOverScreen/ReasonLabel.text = reason
	pass


func _on_key_collected(key_id: String) -> void:
	"""Called when a key is collected"""
	keys_collected += 1
	# Example: Play sound, show particle effect
	# AudioManager.play_sfx(key_sound)
	# $KeyParticles.emitting = true
	
	# Example: Update UI
	# $UI/KeyCounter.text = "%d / %d" % [keys_collected, total_keys]
#endregion

#region Your Custom Methods
func add_score(points: int) -> void:
	"""Add to player's score"""
	score += points
	# Update UI, play sound, etc.


func _on_time_up() -> void:
	"""Called when time runs out"""
	# Decide: Is time up a fail or just end?
	if score >= star_thresholds[0]:
		complete_game(score)
	else:
		fail_game("Time's up!")


# Example: Player hits an enemy
func _on_enemy_hit() -> void:
	add_score(10)


# Example: Player finds a key
func _on_key_found(key_node: Node) -> void:
	var key_id = "key_%d" % keys_collected
	collect_key(key_id)  # This adds to keys_found_this_session
	key_node.queue_free()


# Example: Player reaches goal
func _on_goal_reached() -> void:
	complete_game(score)


# Example: Player dies
func _on_player_died() -> void:
	fail_game("You died!")
#endregion

#region Exit Handling
func request_exit() -> void:
	"""
	Called when player presses ESC.
	Override to show confirmation dialog.
	"""
	# Option 1: Exit immediately
	# _confirm_exit()
	
	# Option 2: Show confirmation
	pause_game()
	# $UI/ExitConfirmDialog.show()
	
	# For this template, just pause
	if state == MinigameState.PLAYING:
		pause_game()
	elif state == MinigameState.PAUSED:
		resume_game()
#endregion

#region UI Button Handlers (Example)
func _on_start_button_pressed() -> void:
	start_game()


func _on_pause_button_pressed() -> void:
	toggle_pause()


func _on_quit_button_pressed() -> void:
	_confirm_exit()


func _on_retry_button_pressed() -> void:
	# Restart the minigame
	get_tree().reload_current_scene()
#endregion
