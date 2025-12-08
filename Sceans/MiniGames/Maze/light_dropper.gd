extends Node2D

@onready var main_character: CharacterBody2D = $"../MainCharacter"
@onready var lantern_dropper: Node2D = $"."
@onready var lantern_label: Label = $"../MainCharacter/LanternLabel"
@onready var time_label: Label = $"../MainCharacter/TimerLabel"

var lantern_scene := preload("lantern.tscn")

@export var MAX_LANTERNS := 10
var placed_lantern := 0
var elapsed_time := 0.0

func _ready() -> void:
	time_label.text = "00:00"
	var default_light = main_character.get_node("PointLight2D")
	if default_light:
		default_light.enabled = false

func _input(event):
	if event.is_action_pressed("space"): 
		if placed_lantern < MAX_LANTERNS:
			drop_dot()

func drop_dot():
	placed_lantern += 1

	var dot = lantern_scene.instantiate()
	dot.position = main_character.position
	add_child(dot)

	lantern_label.text = "Available Lanterns: " + str(MAX_LANTERNS - placed_lantern)

func _process(delta: float) -> void:
	elapsed_time += delta
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60

	time_label.text = str(minutes) + ":" + str(seconds)
