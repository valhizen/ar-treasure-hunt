extends Node2D

@onready var main_character: CharacterBody2D = $Player
@onready var timer_label: Label = $Player/TimerLabel


@export var MAX_LANTERNS := 10
var placed_lantern := 0
var elapsed_time := 0.0

func _ready() -> void:
	timer_label.text = "00:00"

func _process(delta: float) -> void:
	elapsed_time += delta
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60

	timer_label.text = str(minutes) + ":" + str(seconds)
