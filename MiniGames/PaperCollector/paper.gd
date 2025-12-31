extends Area2D

signal collected

@export var fall_speed := 150.0

@export var hover_amplitude_max := 20.0
@export var hover_frequency_max := 3.0
@export var sway_amplitude_max := 30.0
@export var sway_frequency_max := 1.5

var time_alive := 0.0
var start_x := 0.0
var _screen_height := 0.0

# Randomized per instance (internal only)
var hover_amp := 0.0
var hover_freq := 0.0
var sway_amp := 0.0
var sway_freq := 0.0
var phase := 0.0

func _ready():
	_screen_height = get_viewport().get_visible_rect().size.y
	start_x = position.x
	body_entered.connect(_on_body_entered)

	randomize()

	hover_amp = randf_range(0.1 * hover_amplitude_max, hover_amplitude_max)
	hover_freq = randf_range(0.1 * hover_frequency_max , hover_frequency_max)

	sway_amp = randf_range(0.1 * sway_amplitude_max, sway_amplitude_max)
	sway_freq = randf_range(0.1, sway_frequency_max)

	phase = randf_range(0.0, TAU)

func _process(delta):
	time_alive += delta

	# Fall
	position.y += fall_speed * delta

	# Hover
	var hover = sin(time_alive * hover_freq + phase) * hover_amp

	# Sway
	var sway = sin(time_alive * sway_freq + phase) * sway_amp

	position.x = start_x + sway
	position.y += hover * delta

	if position.y > _screen_height + 20:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		collected.emit()
		queue_free()
