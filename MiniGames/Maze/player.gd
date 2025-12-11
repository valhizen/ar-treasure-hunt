extends CharacterBody2D

@export var player_speed : float = 150.0


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

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
