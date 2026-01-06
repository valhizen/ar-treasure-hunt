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
@export var respawn_delay := 1.2

@onready var death_sfx: AudioStreamPlayer   = $DeathSFX
@onready var damage_sfx: AudioStreamPlayer = $DamageSFX
@onready var lantern_sfx: AudioStreamPlayer = $LanternSFX
@onready var coin_sfx: AudioStreamPlayer  = $CoinSFX
@onready var victory_sfx: AudioStreamPlayer = $VictorySFX


const LANTERN = preload("uid://bkxwu64qvj15")

var placed_lantern  := 0
var coins_collected := 0
var current_health  := max_health
var is_flashing     := false
var spawn_pos       : Vector2
var is_dead         := false
var has_finished    := false

func _ready() -> void:
	spawn_pos = position
	game_manager.set_lanterns(lantern_count)
	game_manager.set_health(current_health)
	animated_sprite_2d.play("idle_down")
	
func _input(event):
	if event.is_action_pressed("place_lantern"): 
		if placed_lantern < lantern_count:
			place_lantern()
	
func _physics_process(_delta: float) -> void:
	if is_dead:
		return
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
	play_sfx(damage_sfx)
	
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
	if is_dead:
		return

	is_dead = true
	play_sfx(damage_sfx)
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	animated_sprite_2d.modulate = Color(1, 0, 0)

	await get_tree().create_timer(respawn_delay).timeout
	respawn()

func respawn():
	for lantern in get_tree().get_nodes_in_group("lantern"):
		lantern.queue_free()
		
	current_health = max_health
	game_manager.set_health(current_health)
	
	placed_lantern = 0
	game_manager.set_lanterns(lantern_count)
	position = spawn_pos
	
	

	animated_sprite_2d.modulate = Color(1, 1, 1)
	animated_sprite_2d.play("idle_down")

	is_dead = false
	is_flashing = false
	set_physics_process(true)

	

func collect_coin():
	play_sfx(coin_sfx)
	game_manager.add_coin()
	
func place_lantern():
	if placed_lantern >= lantern_count:
		return

	play_sfx(lantern_sfx)
	placed_lantern += 1
	game_manager.set_lanterns(lantern_count - placed_lantern)

	var lantern = LANTERN.instantiate()
	lantern.global_position = global_position
	get_parent().add_child(lantern)
	
func reach_finish():
	if has_finished:
		return

	has_finished = true
	play_sfx(victory_sfx)
	velocity = Vector2.ZERO
	set_physics_process(false)

	animated_sprite_2d.play("idle_down")
	game_manager.level_completed()
	
func play_sfx(player: AudioStreamPlayer, min_pitch := 0.95, max_pitch := 1.05):
	if player.playing:
		player.stop()
		
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.play()
