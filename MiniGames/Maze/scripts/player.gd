extends CharacterBody2D

@export var player_speed : float = 150.0
@export var max_health: int = 100
@export var flash_duration: float = 0.1
@export var flash_count: int = 5
@onready var game_manager = get_node("../GameManager")


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var coins_collected := 0
var current_health: int = max_health
var is_flashing: bool = false

func _ready() -> void:
	animated_sprite_2d.play("idle_down")
	
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

func die():
	print("Player died!")
	# TODO: Add death logic (game over screen, restart, etc.)
	animated_sprite_2d.modulate = Color(1, 0, 0, 1)  # Turn red to indicate death

func collect_coin():
	game_manager.add_coin()
