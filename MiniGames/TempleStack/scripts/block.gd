extends CharacterBody2D

@export var move_speed: float = 80.0
@export var fall_speed: float = 400.0

signal landed(final_position: Vector2)
signal spawn()

enum DIR{
	LEFT = -1,
	RIGHT = 1
}

var moving_sideways: bool = true
var direction: float = DIR.LEFT 
var has_landed: bool = false

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft


func _physics_process(delta: float) -> void:
	if has_landed:
		return
	move_block()


func _on_game_drop() -> void:
	# Switch to falling mode
	print(global_position.x)
	if global_position.x < 147 or global_position.x  > 330:
		moving_sideways = true
	else:
		moving_sideways = false
		


func move_block() -> void:
	if moving_sideways:
		# Auto left-right motion
		velocity.x = move_speed * direction
		velocity.y = 0.0
		move_and_slide()

		# If we hit a wall, bounce back
		if is_on_wall():
			direction *= -1 # reverse the direction
	else:
		# Falling straight down
		velocity.x = 0.0
		velocity.y = fall_speed
		move_and_slide()

		# When we hit the floor, we "land"
		if is_on_floor() and !has_landed:
			has_landed = true
			velocity = Vector2.ZERO
			landed.emit(global_position) # tell the Game our final position
			spawn.emit() 
			set_physics_process(false)
