extends Node2D

signal coins_changed(value)
signal health_changed(value)

@onready var player: CharacterBody2D = $"../Player"
@onready var timer_label: Label = $"../Player/TimerLabel"

var coins := 0
var player_health := 100
var elapsed_time := 0.0

func _ready() -> void:
	update_display()

func _process(delta: float) -> void:
	elapsed_time += delta
	update_display()

func add_coin():
	coins += 1
	emit_signal("coins_changed", coins)
	update_display()

func set_health(value):
	player_health = clamp(value, 0, 100)
	emit_signal("health_changed", player_health)
	update_display()

func update_display():
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60

	timer_label.text = (
		"Time: %02d:%02d\nCoins: %d\nHealth: %d" %
		[minutes, seconds, coins, player_health]
	)
