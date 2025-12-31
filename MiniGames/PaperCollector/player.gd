extends CharacterBody2D

@export var speed: float = 400.0

var _screen_width : float 

func _ready():
	_screen_width = get_viewport().get_visible_rect().size.x

func _physics_process(_delta):
	# Get input direction
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Move the player
	velocity.x = direction * speed
	velocity.y = 0  # Stay on ground
	
	move_and_slide()
	
	# Keep player within screen bounds
	position.x = clamp(position.x, 0, _screen_width)
