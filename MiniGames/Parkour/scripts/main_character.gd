extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var main_character: CharacterBody2D = $"."
@onready var enemies: Node2D = $"../Enemies"
@onready var checkpoint: Area2D = $"../Checkpoint"
@onready var coins: Label = $Coins


# Player controls
@export var player_land_speed: float = 150
@export var player_water_speed: float = 75
var player_speed = player_land_speed

# Platformer states
@export var just_entered_water: bool = false
@export var just_exited_water: bool = false
@export var just_entered_wall: bool = false
@export var just_exited_wall: bool = false
@export var platformer: bool = false
@export var in_water: bool = false
@export var in_wall: bool = false

# Platformer Movement Controls
@export var max_velocity_air: float = 300
@export var max_velocity_water: float = 100
@export var land_gravity: float = 600
@export var water_gravity: float = 20
@export var airtime_rate: float = 10
@export var airtime_threshold: float = 0.5
@export var player_land_jump: float = 300
@export var player_water_jump: float = 150

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var checkpoint_position:Vector2
var coins_collected: int = 0

func _ready() -> void:
	animated_sprite.play("idle_down")
	checkpoint_position = main_character.global_position


func _physics_process(delta: float) -> void:
		if velocity.x == 0:
			animated_sprite.play("idle_down")
		_platformer_physics(delta)



#--------------------
#  Platformer Logics
#--------------------

func _platformer_physics(delta: float) -> void:
	if just_entered_wall:
		in_wall = true
		just_entered_wall = false

	if just_exited_wall:
		in_wall = false
		just_exited_wall = false

	_player_switch_settings()

	if not is_on_floor():
		if in_wall:
			if is_on_wall():
				velocity.y = gravity * delta * 0.5
				animated_sprite.play("idle_left_sideways")
				if Input.is_action_pressed("Left") and Input.is_action_just_pressed("Jump"):
					velocity.x = -player_speed
					velocity.y = -300
				elif Input.is_action_pressed("Right") and Input.is_action_just_pressed("Jump"):
					velocity.x = -player_speed
					velocity.y = -300
		if in_water and (Input.is_action_pressed("Left") or Input.is_action_pressed("Right")):
			velocity.y = 0
		else:
			velocity.y += gravity * delta
			if absf(velocity.y) >= max_velocity:
				velocity.y = max_velocity
			airtime += airtime_rate * delta
	else:
		airtime = 0
	
	# Movement
	if Input.is_action_pressed("Left"):
		animated_sprite.play("run_left")
		velocity.x = -player_speed
	elif Input.is_action_pressed("Right"):
		animated_sprite.play("run_right")
		velocity.x = player_speed
	else:
		velocity.x = 0
	
	if Input.is_action_just_pressed("Jump"):
		if in_water or airtime < airtime_threshold:
			velocity.y = -jump_force
	elif Input.is_action_pressed("Down") and in_water:
		velocity.y = jump_force
	
	move_and_slide()

func _player_switch_settings():
	gravity = land_gravity
	max_velocity = max_velocity_air
	player_speed = player_land_speed
	jump_force = player_land_jump
	
func print():
	main_character.global_position = checkpoint_position
	enemies.queue_free()

func save_checkpoint(position: Vector2):
	checkpoint_position = position

func add_coin():
	coins_collected += 1
	var text = "Coins: " + str(coins_collected)
	coins.text = text
	print(coins_collected)
	
