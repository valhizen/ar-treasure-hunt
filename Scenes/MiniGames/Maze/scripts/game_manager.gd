extends Node2D

@onready var player: CharacterBody2D = $"../Player"
@onready var timer_label: Label = $"../Player/TimerLabel"
@onready var bg_music: AudioStreamPlayer = $"../BGMusic"

@export var coin_score := 100
@export var health_score := 5
@export var time_bonus_max := 1000
@export var lantern_bonus := 50
@export var minigame_id := "bkt_maze"

var coins := 0
var player_health := 100
var elapsed_time := 0.0
var lantern_remaining := 10
var level_finished := false
var final_score := 0

# Score UI nodes
var score_panel: Panel
var score_container: VBoxContainer

func _ready() -> void:
	if not bg_music.playing:
		bg_music.play()
	_create_score_ui()
	update_display()

func _process(delta: float) -> void:
	if level_finished:
		return
	elapsed_time += delta
	update_display()

func add_coin():
	coins += 1
	update_display()

func set_health(value):
	player_health = clamp(value, 0, 100)
	update_display()

func set_lanterns(value: int):
	lantern_remaining = max(value, 0)
	update_display()

func update_display():
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60
	var text := "Time: %02d:%02d\nCoins: %d\nHealth: %d\nLanterns: %d" % [
		minutes, seconds, coins, player_health, lantern_remaining
	]
	
	if level_finished:
		text += "\n\nLEVEL COMPLETE!"
	
	timer_label.text = text

func level_completed():
	level_finished = true
	fade_out_music()
	var score_data = calculate_score()
	print(score_data)
	_show_score_breakdown(score_data)
	_submit_score(score_data)

func calculate_score() -> Dictionary:
	var time_bonus = max(time_bonus_max - int(elapsed_time * 10), 0)
	var coin_points = coins * coin_score
	var health_points = player_health * health_score
	var lantern_points = lantern_remaining * lantern_bonus
	
	final_score = coin_points + health_points + time_bonus + lantern_points
	
	return {
		"coins": coin_points,
		"health": health_points,
		"time": time_bonus,
		"lanterns": lantern_points,
		"total": final_score
	}

func _create_score_ui():
	# Create panel
	score_panel = Panel.new()
	score_panel.visible = false
	score_panel.set_anchors_preset(Control.PRESET_CENTER)
	score_panel.custom_minimum_size = Vector2(400, 350)
	score_panel.position = get_viewport_rect().size / 2 - score_panel.custom_minimum_size / 2
	
	# Add style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.6, 0.2)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	score_panel.add_theme_stylebox_override("panel", style)
	
	# Create container
	score_container = VBoxContainer.new()
	score_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_container.add_theme_constant_override("separation", 15)
	score_container.set("theme_override_constants/margin_left", 30)
	score_container.set("theme_override_constants/margin_right", 30)
	score_container.set("theme_override_constants/margin_top", 30)
	score_container.set("theme_override_constants/margin_bottom", 30)
	
	score_panel.add_child(score_container)
	add_child(score_panel)

func _show_score_breakdown(score_data: Dictionary):
	# Clear existing children
	for child in score_container.get_children():
		child.queue_free()
	
	# Title
	var title = Label.new()
	title.text = "LEVEL COMPLETE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	score_container.add_child(title)
	
	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 10
	score_container.add_child(spacer1)
	
	# Score breakdown
	_add_score_line("Coins Collected:", "%d × %d = %d" % [coins, coin_score, score_data["coins"]])
	_add_score_line("Health Remaining:", "%d × %d = %d" % [player_health, health_score, score_data["health"]])
	_add_score_line("Lanterns Left:", "%d × %d = %d" % [lantern_remaining, lantern_bonus, score_data["lanterns"]])
	_add_score_line("Time Bonus:", "%d" % score_data["time"])
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 3)
	score_container.add_child(separator)
	
	# Total score
	var total_container = HBoxContainer.new()
	total_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var total_label = Label.new()
	total_label.text = "TOTAL SCORE: "
	total_label.add_theme_font_size_override("font_size", 28)
	total_label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	var total_value = Label.new()
	total_value.text = str(score_data["total"])
	total_value.add_theme_font_size_override("font_size", 32)
	total_value.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	
	total_container.add_child(total_label)
	total_container.add_child(total_value)
	score_container.add_child(total_container)
	
	# Show panel with animation
	score_panel.modulate.a = 0
	score_panel.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(score_panel, "modulate:a", 1.0, 0.5)

func _add_score_line(label_text: String, value_text: String):
	var hbox = HBoxContainer.new()
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(0.8, 1, 0.8))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	hbox.add_child(label)
	hbox.add_child(value)
	score_container.add_child(hbox)

func _submit_score(score_data: Dictionary) -> void:
	var response = await ScoreManager.submit_score(minigame_id, score_data["total"], {
		"time_taken": elapsed_time,
		"coins_collected": coins,
		"health_remaining": player_health,
		"lanterns_remaining": lantern_remaining,
		"coin_points": score_data["coins"],
		"health_points": score_data["health"],
		"time_bonus": score_data["time"],
		"lantern_points": score_data["lanterns"],
		"success": true
	})
	
	if response.success:
		print("[GameManager] Score submitted: %d" % score_data["total"])
	else:
		print("[GameManager] Score queued for later: %s" % response.get("error", "unknown"))

func fade_out_music(duration := 1.0):
	var tween = get_tree().create_tween()
	tween.tween_property(bg_music, "volume_db", -40, duration)
	tween.finished.connect(func(): bg_music.stop())
