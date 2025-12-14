extends CharacterBody2D

@onready var game_manager = get_node("../GameManager")
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

@export var player_speed   := 180.0
@export var max_health     := 100
@export var flash_duration := 0.1
@export var flash_count    := 5
@export var lantern_count  := 10
@export var shake_strength := 10.0     
@export var shake_duration := 0.15

const LANTERN = preload("uid://bkxwu64qvj15")

var placed_lantern  := 0
var coins_collected := 0
var current_health  := max_health
var is_flashing     := false

func _ready() -> void:
	animated_sprite_2d.play("idle_down")
	
func _input(event):
	if event.is_action_pressed("place_lantern"): 
		if placed_lantern < lantern_count:
			place_lantern()
	
func _physics_process(_delta: float) -> void:
	var input_direction = Input.get_vector("Left", "Right", "Up", "Down")
	velocity = input_direction * player_speed
	update_animation(input_direction)
	move_and_slide()
	
func update_animation(direction : Vector2):
	if direction.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite_2d.play("run_right")
			else:
				animated_sprite_2d.play("run_left")	
		else:
			if direction.y > 0:
				animated_sprite_2d.play("run_down")
			else:
				animated_sprite_2d.play("run_up")
	else:
		var current_animation = animated_sprite_2d.animation
		if "run" in current_animation:
			var idle_dir = current_animation.replace("run", "idle")
			animated_sprite_2d.play(idle_dir)
		elif not "idle" in current_animation:
			animated_sprite_2d.play("idle_down")

func take_damage(amount: int):
	if is_flashing:
		return  # invincibility frames // no one hearsa word  they say
	camera_shake()
	
	current_health -= amount
	game_manager.set_health(current_health)
	
	if current_health <= 0:
		die()
	else:
		flash()

func flash():
	if is_flashing:
		return
	
	is_flashing = true
	
	# Flash the sprite multiple times
	for i in flash_count:
		animated_sprite_2d.modulate.a = 0.3  # Make semi-transparent
		await get_tree().create_timer(flash_duration).timeout
		animated_sprite_2d.modulate.a = 1.0  # Make fully visible
		await get_tree().create_timer(flash_duration).timeout
	
	is_flashing = false

func camera_shake():
	var elapsed := 0.0
	var original_offset := camera.offset

	while elapsed < shake_duration:
		var strength = shake_strength * (1.0 - elapsed / shake_duration)
		camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	camera.offset = original_offset


func die():
	print("Player died!")
	# TODO: Add death logic (game over screen, restart, etc.)
	animated_sprite_2d.modulate = Color(1, 0, 0, 1)  # Turn red to indicate death

func collect_coin():
	game_manager.add_coin()
	
func place_lantern():
	placed_lantern += 1
	var lantern = LANTERN.instantiate()
	lantern.global_position = global_position
	get_parent().add_child(lantern)
