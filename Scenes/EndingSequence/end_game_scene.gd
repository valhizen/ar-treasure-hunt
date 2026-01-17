extends Control

# Page references
@onready var page1 = $Page1
@onready var page2 = $Page2
@onready var page3 = $Page3

# Content references
@onready var stats_label = $Page2/StatsLabel
@onready var credits_label = $Page3/CreditsLabel

# Customizable fade-in times for each page (in seconds)
@export var page1_fade_time: float = 2.0
@export var page2_fade_time: float = 1.5
@export var page3_fade_time: float = 1.8

# Current page tracker
var current_page: int = 1

func _ready():
	# Start with all pages invisible
	page1.modulate.a = 0
	page2.modulate.a = 0
	page3.modulate.a = 0
	
	# Show only page 1
	page1.visible = true
	page2.visible = false
	page3.visible = false
	
	# Fade in page 1
	fade_in_page(page1, page1_fade_time)

func fade_in_page(page: Control, fade_time: float):
	var tween = create_tween()
	tween.tween_property(page, "modulate:a", 1.0, fade_time)

func fade_out_then_show_next(current: Control, next: Control, fade_time: float):
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

func _on_continue_button_1_pressed():
	current_page = 2
	fade_out_then_show_next(page1, page2, page2_fade_time)

func _on_continue_button_2_pressed():
	current_page = 3
	fade_out_then_show_next(page2, page3, page3_fade_time)

func _on_continue_button_3_pressed():
	get_tree().change_scene_to_file("res://Scenes/Core/MainMenu/main_menu.tscn")

# Call this function to set stats from a dictionary
func set_stats(minigame_scores: Dictionary):
	if minigame_scores.is_empty():
		# Generate random placeholder scores if none provided
		minigame_scores = {
			"Circuit Breaker": randi_range(800, 2500),
			"Power Grid Repair": randi_range(800, 2500),
			"Debris Cleanup": randi_range(800, 2500),
			"Cable Reconnect": randi_range(800, 2500),
			"Water Pipe Fix": randi_range(800, 2500),
			"Traffic Reroute": randi_range(800, 2500),
			"Building Stabilization": randi_range(800, 2500),
			"Signal Restoration": randi_range(800, 2500),
			"Emergency Dispatch": randi_range(800, 2500),
			"Resource Allocation": randi_range(800, 2500),
			"Hazard Containment": randi_range(800, 2500),
			"Final Restoration": randi_range(800, 2500)
		}
	
	var stats_text = ""
	for game_name in minigame_scores.keys():
		stats_text += game_name + ": " + str(minigame_scores[game_name]) + "\n"
	stats_label.text = stats_text.strip_edges()

# Call this function to set credits text
func set_credits(credits_text: String):
	credits_label.text = credits_text
