extends MinigameBase
## PaperCollector - Catch falling papers minigame
## Collect papers before they hit the ground

#region Custom Configuration
@export_group("Paper Settings")
@export var paper_scene: PackedScene
@export var initial_spawn_interval := 2.0
@export_range(0.0, 1.0, 0.01) var spawn_time_decline_factor := 0.85
@export var total_papers := 30
#endregion

#region Node References
@onready var player = $Player
@onready var score_label: Label = $UI/ScoreLabel
@onready var completed_stats: Label = $UI/CompletedStats
@onready var bg_music: AudioStreamPlayer = $BGMusic
@onready var collect_sfx: AudioStreamPlayer = $CollectSFX
@onready var game_over_sfx: AudioStreamPlayer = $GameOverSFX
#endregion

#region Game State
var spawn_timer := 0.0
var spawn_interval := initial_spawn_interval
var dropped_papers := 0
var collected_papers := 0
var active_papers := 0
var _screen_width := 0.0
#endregion

func _ready():
	_screen_width = get_viewport().get_visible_rect().size.x
	super._ready()  # Call parent ready

#region MinigameBase Overrides
func _setup_game() -> void:
	"""Initialize paper collector"""
	print("[PaperCollector] Setting up...")
	
	dropped_papers = 0
	collected_papers = 0
	active_papers = 0
	current_score = 0
	spawn_timer = 0.0
	spawn_interval = initial_spawn_interval
	
	score_label.text = "Papers: 0 / " + str(total_papers)
	score_label.visible = true
	completed_stats.visible = false
	player.visible = true
	
	# Clear any existing papers
	for child in get_children():
		if child.is_in_group("paper"):
			child.queue_free()

func _start_game() -> void:
	"""Start collecting papers"""
	print("[PaperCollector] Game started!")
	bg_music.play()

func _update_game(delta: float) -> void:
	"""Spawn papers over time"""
	spawn_timer += delta
	if spawn_timer >= spawn_interval and dropped_papers < total_papers:
		spawn_timer = 0.0
		dropped_papers += 1
		spawn_paper()

func _on_time_up() -> void:
	"""Time ran out - end game"""
	print("[PaperCollector] Time's up!")
	game_over_sfx.play()
	complete_game()

func _cleanup_game() -> void:
	"""Clean up papers and UI"""
	player.visible = false
	bg_music.stop()
	
	for child in get_children():
		if child.is_in_group("paper"):
			child.queue_free()

func _calculate_final_score() -> int:
	"""Calculate final score with bonuses"""
	var base = collected_papers * 100
	var completion_bonus = 500 if collected_papers >= total_papers else 0
	var efficiency_ratio = float(collected_papers) / total_papers if total_papers > 0 else 0.0
	var efficiency_bonus = int(efficiency_ratio * 300)
	
	# Store game data for analytics and score submission
	game_data["collected_papers"] = collected_papers
	game_data["total_papers"] = total_papers
	game_data["dropped_papers"] = dropped_papers
	game_data["completion_bonus"] = completion_bonus
	game_data["efficiency"] = efficiency_ratio
	game_data["perfect_collection"] = collected_papers >= total_papers
	
	var final_score = base + completion_bonus + efficiency_bonus
	
	print("[PaperCollector] Final Score Calculation:")
	print("  Base (papers × 100): %d" % base)
	print("  Completion Bonus: %d" % completion_bonus)
	print("  Efficiency Bonus: %d" % efficiency_bonus)
	print("  TOTAL: %d" % final_score)
	
	return final_score

func _calculate_rewards(score: int, stars: int) -> Dictionary:
	"""Calculate currency and item rewards"""
	var rewards = {
		"currency": 10 + (stars * 15) + (collected_papers * 2),
		"items": []
	}
	
	# Special reward for perfect collection with high stars
	if collected_papers >= total_papers and stars >= 2:
		rewards["items"].append({
			"id": "paper_master_badge",
			"amount": 1,
			"special": true
		})
	
	# Bonus for high efficiency
	if game_data.get("efficiency", 0.0) >= 0.9 and stars >= 1:
		rewards["items"].append({
			"id": "efficiency_medal",
			"amount": 1,
			"special": false
		})
	
	print("[PaperCollector] Rewards: %d currency, %d items" % [rewards["currency"], rewards["items"].size()])
	
	return rewards

#endregion

#region Paper Management
func spawn_paper() -> void:
	"""Spawn a new paper at random X position"""
	if not is_playing():
		return
	
	if not paper_scene:
		push_error("[PaperCollector] paper_scene not set!")
		return
	
	var paper = paper_scene.instantiate()
	var spawn_x = randf_range(50, _screen_width - 50)
	paper.position = Vector2(spawn_x, -50)
	paper.add_to_group("paper")
	active_papers += 1
	
	# Connect signals
	if paper.has_signal("collected"):
		paper.collected.connect(_on_paper_collected)
	else:
		push_warning("[PaperCollector] Paper doesn't have 'collected' signal!")
	
	if paper.has_signal("tree_exited"):
		paper.tree_exited.connect(_on_paper_removed)
	
	add_child(paper)
	print("[PaperCollector] Paper spawned at x=%d (Total: %d/%d)" % [spawn_x, dropped_papers, total_papers])

func _on_paper_collected() -> void:
	"""Called when player collects a paper"""
	if not is_playing():
		return
	
	collected_papers += 1
	
	# Speed up spawning as game progresses
	spawn_interval *= spawn_time_decline_factor
	
	# Add score through MinigameBase
	add_score(100)
	
	# Update UI
	score_label.text = "Papers: %d / %d" % [collected_papers, total_papers]
	
	# Play sound
	if collect_sfx:
		collect_sfx.play()
	
	print("[PaperCollector] Paper collected! (%d/%d) Score: %d" % [collected_papers, total_papers, current_score])

func _on_paper_removed() -> void:
	"""Called when a paper is removed (collected or missed)"""
	active_papers -= 1
	
	print("[PaperCollector] Paper removed. Active: %d, Dropped: %d/%d" % [active_papers, dropped_papers, total_papers])
	
	# Check if game should end
	# End ONLY when all papers have been dropped AND none are still active
	if dropped_papers >= total_papers and active_papers == 0:
		print("[PaperCollector] All papers processed! Ending game...")
		if game_over_sfx:
			game_over_sfx.play()
		
		# Show completion UI before ending
		update_completion_ui()
		
		# Wait a moment for player to see results
		await get_tree().create_timer(2.0).timeout
		
		# Submit score before completing
		_submit_score_to_leaderboard()
		
		# Complete the game (this will return to map via MinigameManager)
		complete_game()

#endregion

#region Score Submission
func _submit_score_to_leaderboard() -> void:
	"""Submit score to ScoreManager"""
	var score_manager = get_node_or_null("/root/ScoreManager")
	if not score_manager:
		push_warning("[PaperCollector] ScoreManager not found!")
		return
	
	var extra_data = {
		"collected_papers": collected_papers,
		"total_papers": total_papers,
		"dropped_papers": dropped_papers,
		"perfect_collection": collected_papers >= total_papers,
		"efficiency": game_data.get("efficiency", 0.0),
		"time_taken": game_data.get("time_taken", 0),
		"stars": game_data.get("stars", 0),
		"success": game_data.get("success", false)
	}
	
	# Submit score (works offline too - queues for later)
	score_manager.submit_score("paper_collector", current_score, extra_data)
	print("[PaperCollector] ✅ Score submitted: %d" % current_score)

#endregion

#region UI Updates
func update_completion_ui() -> void:
	"""Update the completion stats UI"""
	score_label.visible = false
	completed_stats.visible = true
	
	var efficiency = float(collected_papers) / total_papers if total_papers > 0 else 0.0
	var efficiency_percent = int(efficiency * 100)
	
	var message = ""
	if collected_papers >= total_papers:
		message = "🎉 Perfect! All papers collected!\n"
	elif efficiency >= 0.8:
		message = "✨ Great job!\n"
	elif efficiency >= 0.5:
		message = "👍 Good effort!\n"
	else:
		message = "💪 Keep practicing!\n"
	
	message += "\n"
	message += "Papers Collected: %d / %d\n" % [collected_papers, total_papers]
	message += "Efficiency: %d%%\n" % efficiency_percent
	message += "Final Score: %d\n" % current_score
	
	completed_stats.text = message
	
	print("[PaperCollector] " + message.replace("\n", " | "))

#endregion
