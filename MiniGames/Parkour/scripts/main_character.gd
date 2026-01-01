extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var main_character: CharacterBody2D = $"."
@onready var enemies: Node2D = $"../Enemies"
@onready var checkpoint: Area2D = $"../Checkpoint"
@onready var coins: Label = $Coins
@onready var message: Label = $"../message"
@onready var message_2: Label = $"../message2"
@onready var respawn_label: Label = $Respawn

# Player controls
@export var player_land_speed: float = 150
var player_speed = player_land_speed


@export var just_entered_wall: bool = false
@export var just_exited_wall: bool = false
@export var in_wall: bool = false

# Platformer Movement Controls
@export var max_velocity_air: float = 300
@export var land_gravity: float = 600
@export var airtime_rate: float = 10
@export var airtime_threshold: float = 0.5
@export var player_land_jump: float = 300
@export var coins_collected: int = 0

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var checkpoint_position:Vector2


func _ready() -> void:
	animated_sprite.play("idle_down")
	checkpoint_position = main_character.global_position


func _physics_process(delta: float) -> void:
		_update_animation()
		_platformer_physics(delta)

func _update_animation():
	if is_on_wall() and not is_on_floor():
		if animated_sprite.animation != "hanging":
			animated_sprite.play("hanging")
		return

	if velocity.x != 0:
		if velocity.x < 0:
			if animated_sprite.animation != "run_left":
				animated_sprite.play("run_left")
		else:
			if animated_sprite.animation != "run_right":
				animated_sprite.play("run_right")
		return

	# Idle
	if animated_sprite.animation != "idle_down":
		animated_sprite.play("idle_down")

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
				if Input.is_action_pressed("Left") and Input.is_action_just_pressed("Jump"):
					velocity.x = -player_speed
					velocity.y = -300
				elif Input.is_action_pressed("Right") and Input.is_action_just_pressed("Jump"):
					velocity.x = -player_speed
					velocity.y = -300
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
		if airtime < airtime_threshold:
			velocity.y = -jump_force
	
	move_and_slide()

func _player_switch_settings():
	gravity = land_gravity
	max_velocity = max_velocity_air
	player_speed = player_land_speed
	jump_force = player_land_jump

func wait_seconds(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds, true)
	await timer.timeout

func respawn_countdown() -> void:
	respawn_label.visible = true

	for i in range(4, 0, -1):
		if i == 4:
			respawn_label.text = "You Died!"
			await wait_seconds(1.0)
		else:
			respawn_label.text = "Respawning in .." + str(i)
			await wait_seconds(1.0)

	respawn_label.visible = false

func striked():
	await die()
	main_character.global_position = checkpoint_position
	
	message.text = "You're back \n There's nothing hehe"
	message_2.text = "Sorry, Not Sorry"

	enemies.queue_free()
	

func save_checkpoint(position: Vector2):
	checkpoint_position = position

func add_coin():
	coins_collected += 1
	var text = "Coins: " + str(coins_collected)
	coins.text = text
 
func die():
	get_tree().paused = true
	await respawn_countdown()
	await wait_seconds(0.0)
	main_character.global_position = checkpoint_position
	get_tree().paused = false
	
	
