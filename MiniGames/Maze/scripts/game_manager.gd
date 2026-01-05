extends Node2D



@onready var player: CharacterBody2D = $"../Player"
@onready var timer_label: Label = $"../Player/TimerLabel"
@onready var bg_music: AudioStreamPlayer = $"../BGMusic"
@export var coin_score := 100
@export var health_score := 5
@export var time_bonus_max := 1000
@export var lantern_bonus := 50



var coins := 0
var player_health := 100
var elapsed_time := 0.0
var lantern_remaining := 10
var level_finished := false
var final_score := 0

func _ready() -> void:
	if not bg_music.playing:
		bg_music.play()
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
		text += "\n\n LEVEL COMPLETE!"

	timer_label.text = text


func level_completed():
	level_finished = true
	fade_out_music()

	var text = calculate_score()
	print(text)

	
	

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
	
func fade_out_music(duration := 1.0):
	var tween = get_tree().create_tween()
	tween.tween_property(bg_music, "volume_db", -40, duration)
	tween.finished.connect(func(): bg_music.stop())
