extends CharacterBody2D

@export var forward_speed := 300.0
@export var side_speed := 400.0
@export var min_x := 100
@export var max_x := 500

# Speed increase settings
@export_group("Speed Progression")
@export var max_forward_speed := 600.0  # Maximum speed cap
@export var speed_increase_rate := 15.0  # Speed increase per second
@export var speed_increase_delay := 2.0  # Wait this many seconds before increasing

# Helicopter reference
@export_group("Helicopter")
@export var helicopter: CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var alive := true
var coins := 0
var current_forward_speed := 0.0
var time_alive := 0.0
var has_won := false

func _ready() -> void:
	animated_sprite_2d.play("default")
	current_forward_speed = forward_speed

func _physics_process(delta):
	if not alive and not has_won:
		return
	
	# Track time alive
	time_alive += delta
	
	# Gradually increase speed after delay (only if not won)
	if time_alive > speed_increase_delay and not has_won:
		current_forward_speed = min(
			current_forward_speed + (speed_increase_rate * delta),
			max_forward_speed
		)
	
	# Auto forward movement with increased speed
	velocity.y = -current_forward_speed
	
	# Left / Right movement only (disable if won)
	if not has_won:
		var dir := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		velocity.x = dir * side_speed
	else:
		velocity.x = 0  # No side movement when won
	
	move_and_slide()
	
	# Check for collisions with obstacles (only if not won)
	if not has_won:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# If hit obstacle, make helicopter aggressive
			if collider and collider.is_in_group("obstacle"):
				_trigger_helicopter_aggro()
	
	# Clamp player inside road
	#global_position.x = clamp(global_position.x, min_x, max_x)

func collect_coin(value: int):
	# Increase player coins
	coins += value
	get_node("/root/main/UI").update_coins(coins)

func die():
	if has_won:
		return
	alive = false
	velocity = Vector2.ZERO
	get_node("/root/main/UI").show_game_over()
	get_tree().paused = true

# Optional: Get current speed for UI or other systems
func get_current_speed() -> float:
	return current_forward_speed

func _trigger_helicopter_aggro():
	if helicopter and helicopter.has_method("trigger_aggression"):
		helicopter.trigger_aggression()

func win():
	has_won = true
	alive = true  # Keep alive so player keeps moving
	
	# Freeze camera at current position
	var camera = get_node_or_null("Camera2D")
	if camera:
		# Store current global position
		var cam_global_pos = camera.global_position
		# Remove from player (so it doesn't follow)
		remove_child(camera)
		# Add to main scene at frozen position
		get_node("/root/main").add_child(camera)
		camera.global_position = cam_global_pos
		camera.enabled = true
	
	# Show win screen
	get_node("/root/main/UI").show_win(coins)
