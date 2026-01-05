# lava_boss_arena.gd
extends Node2D

@onready var lava_boss: CharacterBody2D = $LaveBoss
@onready var main_character: CharacterBody2D = $MainCharacte
@onready var arena_camera: Camera2D = $Camera2D2

# Arena bounds
@export_group("Arena Bounds")
@export var arena_left: float = 360.0
@export var arena_right: float = 1210.0

# Camera settings
@export_group("Camera")
@export var camera_position: Vector2 = Vector2(785, 280)
@export var camera_zoom_level: float = 0.6

func _ready() -> void:
	_setup_player()
	_setup_camera()

func _setup_player() -> void:
	if not main_character:
		return
	
	main_character.add_to_group("player")
	main_character.platformer = true
	
	# Disable player's own camera
	var player_camera = main_character.get_node_or_null("Camera2D")
	if player_camera:
		player_camera.enabled = false

func _setup_camera() -> void:
	if not arena_camera:
		return
	
	arena_camera.global_position = camera_position
	arena_camera.zoom = Vector2(camera_zoom_level, camera_zoom_level)
	arena_camera.enabled = true
	arena_camera.make_current()
	arena_camera.position_smoothing_enabled = false

func _physics_process(_delta: float) -> void:
	# Keep player in bounds
	if main_character:
		main_character.global_position.x = clamp(
			main_character.global_position.x,
			arena_left,
			arena_right
		)
	
	# Keep boss in bounds
	if lava_boss:
		lava_boss.global_position.x = clamp(
			lava_boss.global_position.x,
			arena_left,
			arena_right
		)
