extends CharacterBody2D
# Movement settings
@export var speed: float = 200.0
@export var rotation_speed: float = 10.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Direction tracking (0-7)
var current_direction: int = 4  # Start facing south
var target_direction: int = 4

# Animation states
enum AnimState { IDLE, RUN, INTERACT, ATTACK }
var current_anim_state: AnimState = AnimState.IDLE

func _ready():
	update_animation()

func _physics_process(delta):
	# Always look at mouse position
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = mouse_pos - global_position
	target_direction = get_direction_from_vector(direction_to_mouse)
	
	# Check if W is pressed to move forward
	var is_moving_forward = Input.is_action_pressed("forward")
	
	if is_moving_forward:
		# Move in the direction we're facing (towards mouse)
		if current_anim_state == AnimState.IDLE:
			current_anim_state = AnimState.RUN
		
		var move_direction = direction_to_mouse.normalized()
		velocity = move_direction * speed
	else:
		# Stopped - switch to idle
		if current_anim_state == AnimState.RUN:
			current_anim_state = AnimState.IDLE
		velocity = Vector2.ZERO
	
	# Smooth rotation
	smooth_rotate_to_target(delta)
	
	# Update sprite
	update_animation()
	
	move_and_slide()

func _input(event):
	# Example: Press E to interact
	if event.is_action_pressed("ui_accept"):
		play_one_shot_animation(AnimState.INTERACT)

func get_direction_from_vector(vec: Vector2) -> int:
	# Convert vector to one of 8 directions
	# 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
	var angle = vec.angle()  # Returns angle from -PI to PI (right=0, down=PI/2)
	
	# Adjust so that up (negative Y) = 0°
	angle = angle + PI / 2  # Rotate by +90° so up becomes 0
	
	# Normalize to 0-2PI range
	if angle < 0:
		angle += TAU
	
	# Divide circle into 8 sections
	var dir = int(round(angle / (PI / 4))) % 8
	return dir

func smooth_rotate_to_target(delta: float):
	if current_direction == target_direction:
		return
	
	var diff = target_direction - current_direction
	
	# Find shortest rotation path
	if diff > 4:
		diff -= 8
	elif diff < -4:
		diff += 8
	
	var step = sign(diff) * rotation_speed * delta
	
	if abs(diff) < abs(step):
		current_direction = target_direction
	else:
		current_direction = (current_direction + int(sign(diff)) + 8) % 8

func update_animation():
	var anim_name = get_animation_name()
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func get_animation_name() -> String:
	# Direction suffixes matching your animation names
	# 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
	var dir_suffix = ["_n", "_ne", "_e", "_se", "_s", "_sw", "_w", "_nw"][current_direction]
	
	# State prefixes
	match current_anim_state:
		AnimState.IDLE:
			return "idle" + dir_suffix
		AnimState.RUN:
			return "run" + dir_suffix
		AnimState.INTERACT:
			return "interact" + dir_suffix
		AnimState.ATTACK:
			return "attack" + dir_suffix
	
	return "idle_s"  # Fallback

func play_one_shot_animation(state: AnimState):
	# Play animation once, then return to idle
	current_anim_state = state
	update_animation()
	
	# Wait for animation to finish
	await animated_sprite.animation_finished
	current_anim_state = AnimState.IDLE
	update_animation()

# Optional helper functions
func set_direction_instant(dir: int):
	current_direction = dir
	target_direction = dir
	update_animation()

func get_direction_name() -> String:
	var names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[current_direction]
