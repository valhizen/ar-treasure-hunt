extends CharacterBody2D

@export var player_speed: float = 400.0

var _screen_width : float 
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	_screen_width = get_viewport().get_visible_rect().size.x

func _physics_process(_delta):
	var input_x = Input.get_axis("Left", "Right")  # only horizontal
	velocity.x = input_x * player_speed
	velocity.y = 0
	update_animation(Vector2(input_x, 0))
	move_and_slide()
	position.x = clamp(position.x, 0, _screen_width)



func update_animation(direction: Vector2):
	if direction.x != 0:
		if direction.x > 0:
			animated_sprite_2d.play("run_right")
		else:
			animated_sprite_2d.play("run_left")
	else:
		# Idle based on last direction
		if animated_sprite_2d.animation == "run_right":
			animated_sprite_2d.play("idle_right")
		elif animated_sprite_2d.animation == "run_left":
			animated_sprite_2d.play("idle_left")
