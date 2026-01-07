extends Area2D

signal collected

@export var fall_speed: float = 150.0
@export var hover_amplitude_max: float = 20.0
@export var hover_frequency_max: float = 3.0
@export var sway_amplitude_max: float = 30.0
@export var sway_frequency_max: float = 1.5
@export var paper_textures: Array[Texture2D] = []

var time_alive: float = 0.0
var start_x: float = 0.0
var _screen_height: float = 0.0

# Randomized per instance
var hover_amp: float = 0.0
var hover_freq: float = 0.0
var sway_amp: float = 0.0
var sway_freq: float = 0.0
var phase: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	_screen_height = get_viewport().get_visible_rect().size.y
	start_x = position.x
	body_entered.connect(_on_body_entered)
	
	# Randomize movement parameters
	hover_amp = randf_range(0.1 * hover_amplitude_max, hover_amplitude_max)
	hover_freq = randf_range(0.1 * hover_frequency_max, hover_frequency_max)
	sway_amp = randf_range(0.1 * sway_amplitude_max, sway_amplitude_max)
	sway_freq = randf_range(0.1 * sway_frequency_max, sway_frequency_max)
	phase = randf_range(0.0, TAU)
	
	# Pick random texture
	if paper_textures.size() > 0:
		sprite.texture = paper_textures[randi() % paper_textures.size()]

func _process(delta):
	time_alive += delta
	
	# Fall down
	position.y += fall_speed * delta
	
	# Hovering effect
	var hover = sin(time_alive * hover_freq + phase) * hover_amp
	
	# Swaying side to side
	var sway = sin(time_alive * sway_freq + phase) * sway_amp
	position.x = start_x + sway
	position.y += hover * delta
	
	# Remove if off screen
	if position.y > _screen_height + 20:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		collected.emit()
		queue_free()
