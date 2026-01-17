extends Control
## Results Screen - Displays player scores from API
## Attach this to your EndGameScene root node

# Customizable fade-in times for each page (in seconds)
@export var page1_fade_time: float = 2.0
@export var page2_fade_time: float = 1.5
@export var page3_fade_time: float = 1.8

# Current page tracker
var current_page: int = 1

# Node references (will find them automatically)
var page1
var page2
var page3
var stats_label
var credits_label

func _ready():
	# Find nodes in scene
	_setup_nodes()
	
	# Setup page visibility
	_setup_pages()
	
	# Load scores from API
	_load_scores()


func _setup_nodes():
	"""Find all nodes in the scene tree"""
	page1 = get_node_or_null("Page1")
	page2 = get_node_or_null("Page2")
	page3 = get_node_or_null("Page3")
	
	# Try to find stats label in Page2
	if page2:
		stats_label = page2.get_node_or_null("StatsLabel")
	
	# Try to find credits label in Page3
	if page3:
		credits_label = page3.get_node_or_null("CreditsLabel")
		
		# Also check for CreditsLabel as direct child
		if not credits_label:
			credits_label = get_node_or_null("Page3/CreditsLabel")
	
	# Fallback: search entire tree for labels
	if not stats_label:
		for child in get_children():
			if child.name == "StatsLabel":
				stats_label = child
				break
	
	print("[ResultsScreen] Nodes found:")
	print("  Page1: ", page1 != null)
	print("  Page2: ", page2 != null)
	print("  Page3: ", page3 != null)
	print("  StatsLabel: ", stats_label != null)
	print("  CreditsLabel: ", credits_label != null)


func _setup_pages():
	"""Setup initial page visibility and animations"""
	if page1 and page2 and page3:
		# Start with all pages invisible
		page1.modulate.a = 0
		page2.modulate.a = 0
		page3.modulate.a = 0
		
		# Show only page 1
		page1.visible = true
		page2.visible = false
		page3.visible = false
		
		# Fade in page 1
		_fade_in_page(page1, page1_fade_time)


func _fade_in_page(page: Control, fade_time: float):
	"""Fade in a page"""
	if not page:
		return
	var tween = create_tween()
	tween.tween_property(page, "modulate:a", 1.0, fade_time)


func _fade_out_then_show_next(current: Control, next: Control, fade_time: float):
	"""Fade out current page and show next"""
	if not current or not next:
		return
		
	var tween = create_tween()
	
	# Fade out current page
	tween.tween_property(current, "modulate:a", 0.0, 0.5)
	
	# Hide current and show next
	tween.tween_callback(func():
		current.visible = false
		next.visible = true
		next.modulate.a = 0
	)
	
	# Fade in next page
	tween.tween_property(next, "modulate:a", 1.0, fade_time)


# Button callbacks
func _on_continue_button_1_pressed():
	current_page = 2
	if page1 and page2:
		_fade_out_then_show_next(page1, page2, page2_fade_time)


func _on_continue_button_2_pressed():
	current_page = 3
	if page2 and page3:
		_fade_out_then_show_next(page2, page3, page3_fade_time)


func _on_continue_button_3_pressed():
	get_tree().change_scene_to_file("res://Scenes/Core/MainMenu/main_menu.tscn")


# ============================================================================
# SCORE LOADING FROM API
# ============================================================================

func _load_scores():
	"""Load scores from API using AuthManager and NetworkManager"""
	
	# Show loading message
	_update_stats_label("Loading scores...")
	
	# Get AuthManager singleton
	var auth = _get_auth_manager()
	if not auth:
		print("[ResultsScreen] ⚠ AuthManager not found - using placeholder scores")
		_update_stats_label("AuthManager not found\nShowing sample scores...")
		await get_tree().create_timer(1.0).timeout
		_show_placeholder_scores()
		return
	
	# Check if logged in
	if not auth.is_logged_in:
		print("[ResultsScreen] ⚠ Not logged in - using placeholder scores")
		_update_stats_label("Not logged in\nShowing sample scores...")
		await get_tree().create_timer(1.0).timeout
		_show_placeholder_scores()
		return
	
	# Get NetworkManager singleton
	var network = _get_network_manager()
	if not network:
		print("[ResultsScreen] ⚠ NetworkManager not found - using placeholder scores")
		_update_stats_label("NetworkManager not found\nShowing sample scores...")
		await get_tree().create_timer(1.0).timeout
		_show_placeholder_scores()
		return
	
	print("[ResultsScreen] 📊 Loading scores for: %s" % auth.get_full_display_name())
	
	# Make API request
	var response = await network.api_get("/scores/my-scores")
	
	if not response.success:
		var error_msg = response.get("error", "Connection failed")
		push_error("[ResultsScreen] Failed to load scores: " + error_msg)
		_update_stats_label("❌ Error loading scores\n" + error_msg)
		await get_tree().create_timer(2.0).timeout
		_show_placeholder_scores()
		return
	
	var data = response.data
	
	# Check if user has any scores
	if not data.has("scores") or data.scores.size() == 0:
		print("[ResultsScreen] 📊 No scores found - new player")
		_update_stats_label("No games played yet!\n\nPlay some minigames to see\nyour scores here.")
		return
	
	# Build scores dictionary
	var minigame_scores = {}
	for score_entry in data.scores:
		var minigame_id = score_entry.minigame_id
		var score = score_entry.score
		minigame_scores[minigame_id] = score
	
	# Display scores
	_display_scores(minigame_scores)
	
	# Add summary
	var total_score = data.get("total_score", 0)
	var minigames_played = data.get("minigames_played", 0)
	var average_score = data.get("average_score", 0)
	
	var summary = "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	summary += "📊 SUMMARY\n"
	summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	summary += "Player: %s\n" % auth.get_player_name()
	summary += "Team: %s\n" % auth.get_team_name()
	summary += "\nTotal Score: %s\n" % str(total_score)
	summary += "Games Played: %s\n" % str(minigames_played)
	summary += "Average Score: %s\n" % str(average_score)
	summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	_append_to_stats_label(summary)
	
	print("[ResultsScreen] ✅ Scores loaded successfully!")
	print("   Total: %d | Games: %d | Average: %d" % [total_score, minigames_played, average_score])


func _display_scores(minigame_scores: Dictionary):
	"""Display scores with medals"""
	if minigame_scores.is_empty():
		_show_placeholder_scores()
		return
	
	var stats_text = "🎮 YOUR GAME SCORES\n"
	stats_text += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	
	# Sort by score (highest first)
	var sorted_games = minigame_scores.keys()
	sorted_games.sort_custom(func(a, b): return minigame_scores[a] > minigame_scores[b])
	
	var rank = 1
	for game_name in sorted_games:
		var score = minigame_scores[game_name]
		var medal = ""
		if rank == 1:
			medal = "🥇 "
		elif rank == 2:
			medal = "🥈 "
		elif rank == 3:
			medal = "🥉 "
		else:
			medal = "   "
		
		stats_text += medal + game_name + ": " + str(score) + "\n"
		rank += 1
	
	_update_stats_label(stats_text.strip_edges())


func _show_placeholder_scores():
	"""Show random placeholder scores"""
	var placeholder_scores = {
		"Circuit Breaker": randi_range(800, 2500),
		"Power Grid Repair": randi_range(800, 2500),
		"Debris Cleanup": randi_range(800, 2500),
		"Cable Reconnect": randi_range(800, 2500),
		"Water Pipe Fix": randi_range(800, 2500),
		"Traffic Reroute": randi_range(800, 2500),
		"Building Stabilization": randi_range(800, 2500),
		"Signal Restoration": randi_range(800, 2500),
	}
	_display_scores(placeholder_scores)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _get_auth_manager():
	"""Get AuthManager singleton safely"""
	return get_node_or_null("/root/AuthManager")


func _get_network_manager():
	"""Get NetworkManager singleton safely"""
	return get_node_or_null("/root/NetworkManager")


func _update_stats_label(text: String):
	"""Update stats label text"""
	if stats_label:
		stats_label.text = text
	else:
		print("[ResultsScreen] Stats: ", text)


func _append_to_stats_label(text: String):
	"""Append text to stats label"""
	if stats_label:
		stats_label.text += text
	else:
		print("[ResultsScreen] Stats: ", text)


# ============================================================================
# PUBLIC API (for external calls)
# ============================================================================

func set_credits(credits_text: String):
	"""Set credits text"""
	if credits_label:
		credits_label.text = credits_text
