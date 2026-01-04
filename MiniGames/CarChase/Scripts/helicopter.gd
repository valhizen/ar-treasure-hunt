extends CharacterBody2D

# ===== TUNING =====
@export var forward_speed := 260.0
@export var side_follow_strength := 6.0
@export var aggression_gain := 30.0
@export var player: CharacterBody2D

# ===== AGGRESSION SETTINGS =====
@export_group("Aggression")
@export var aggro_duration := 1.2  # How long aggression lasts
@export var aggro_speed_boost := 2.0  # Extra speed when aggressive
@export var aggro_follow_strength := 2.0  # Follow strength when aggressive
@export var collision_damage_cooldown := 0.5  # Prevent multiple hits

# ===== IDLE BEHAVIOR =====
@export_group("Idle Behavior")
@export var idle_y_offset := 150.0  # How far above player to stay when calm
@export var idle_drift_amount := 30.0  # Side to side drift distance
@export var drift_back_strength := 2.0  # How fast it drifts back off screen

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prop_sound: AudioStreamPlayer2D = $Propeller
@onready var siren_sound: AudioStreamPlayer2D = $Siren

var base_forward_speed := 0.0
var is_aggressive := false
var aggro_timer := 0.0
var collision_timer := 0.0
var drift_time := 0.0

func _ready():
	sprite.play("fly")
	prop_sound.play()
	
	# Apply speed reduction based on deaths
	var ui = get_node_or_null("/root/main/UI")
	if ui and ui.has_method("get_speed_multiplier"):
		var multiplier = ui.get_speed_multiplier()
		forward_speed *= multiplier
		aggro_speed_boost *= multiplier
		aggro_duration *= multiplier
	
	base_forward_speed = forward_speed

func _physics_process(delta):
	if player == null or not player.alive:
		return
	
	# Match player's speed progression
	if player.has_method("get_current_speed"):
		var player_speed = player.get_current_speed()
		base_forward_speed = player_speed
	
	# Handle aggression timer
	if is_aggressive:
		aggro_timer -= delta
		if aggro_timer <= 0:
			_calm_down()
	
	# Handle collision cooldown
	if collision_timer > 0:
		collision_timer -= delta
	
	drift_time += delta
	
	if is_aggressive:
		_aggressive_behavior(delta)
	else:
		_idle_behavior(delta)
	
	move_and_slide()
	
	# Check collision with player only when aggressive
	if is_aggressive and collision_timer <= 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision.get_collider() == player:
				_on_player_collision()
				break

func _idle_behavior(delta):
	# Target position: behind player (add to stay behind since player moves up/negative Y)
	var target_y = player.global_position.y + idle_y_offset
	var y_diff = target_y - global_position.y
	
	# Smoothly drift towards off-screen position
	# Don't match player speed, just drift to maintain offset
	velocity.y = y_diff * drift_back_strength
	
	# Gentle side-to-side drift
	var drift_x = sin(drift_time * 2.0) * idle_drift_amount
	var target_x = player.global_position.x + drift_x
	var x_diff = target_x - global_position.x
	velocity.x = x_diff * 2.0
	
	# Reset sprite color
	sprite.modulate = Color.WHITE

func _aggressive_behavior(delta):
	# Flash sprite when aggressive
	sprite.modulate = Color(1.5, 0.5, 0.5) if int(aggro_timer * 10) % 2 == 0 else Color.WHITE
	
	# Slightly faster forward movement
	velocity.y = -(base_forward_speed + aggro_speed_boost)
	
	# Smooth tracking towards player (less aggressive)
	var x_diff := player.global_position.x - global_position.x
	var y_diff := player.global_position.y - global_position.y
	
	velocity.x = x_diff * aggro_follow_strength
	# Very gently move down towards player
	velocity.y += y_diff * aggro_follow_strength * 0.1

func _on_player_collision():
	player.die()
	collision_timer = collision_damage_cooldown

func increase_aggression():
	base_forward_speed += aggression_gain

func _become_aggressive():
	is_aggressive = true
	aggro_timer = aggro_duration
	prop_sound.stop()
	siren_sound.play()

func _calm_down():
	is_aggressive = false
	sprite.modulate = Color.WHITE
	prop_sound.play()
	siren_sound.stop()
	
# Call this from other scripts when player does something to anger the helicopter
func trigger_aggression():
	_become_aggressive()
