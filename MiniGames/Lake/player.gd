extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_character: CharacterBody2D = $"."

# Player controls
@export var player_land_speed: float = 150
@export var player_water_speed: float = 75
var player_speed = player_land_speed

# Platformer states
@export var just_entered_water: bool = false
@export var just_exited_water: bool = false
@export var in_water: bool = false

# Platformer Movement Controls
@export var max_velocity_air: float = 300
@export var max_velocity_water: float = 100
@export var land_gravity: float = 600
@export var water_gravity: float = 20
@export var airtime_rate: float = 10
@export var airtime_threshold: float = 0.5
@export var player_land_jump: float = 300
@export var player_water_jump: float = 150

# --- Platformer feel tuning ---
@export var land_accel := 1200.0
@export var land_friction := 1800.0

@export var water_accel := 400.0
@export var water_drag := 6.0
@export var water_buoyancy := 30.0

@export var jump_buffer_time := 0.15
@export var coyote_time := 0.12
@export var jump_cut_multiplier := 0.45
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.3
@export var bullet_spawn_offset: float = 20.0

# Heatlh
@export var player_health: float = 100.0
@export var max_health: float = 100.0

var can_shoot: bool = true
var last_aim_direction: Vector2 = Vector2.RIGHT

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var jump_buffer := 0.0
var coyote_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	var current_scene := get_tree().current_scene
	
	if has_node("Hitbox") and current_scene.name == "Bkt-lake-minigame":
		hitbox = $Hitbox
		hitbox.monitoring = false
		hitbox.connect("hit_corrupter", Callable(self, "_on_hit_corrupter"))

func _physics_process(delta: float) -> void:
	_platformer_physics(delta)

func take_damage(amount: float) -> void:
	player_health -= amount
	player_health = max(0, player_health)
	
	# Optional: Add visual feedback
	print("Player health: ", player_health)
	
	if player_health <= 0:
		_player_die()

func _player_die() -> void:
	print("Player died!")
	
	# Disable player controls
	set_physics_process(false)
	set_process_input(false)
	
	# Show death screen
	var death_screen = get_tree().get_first_node_in_group("death_screen")
	if death_screen and death_screen.has_method("show_death_screen"):
		death_screen.show_death_screen()
	else:
		# Fallback if death screen not found
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func _platformer_physics(delta: float) -> void:
	# --- Water enter/exit ---
	if just_entered_water:
		velocity.x *= 0.6
		velocity.y = min(velocity.y, 40)
		in_water = true
		just_entered_water = false

	if just_exited_water:
		in_water = false
		just_exited_water = false

	_player_switch_settings()

	# --- Timers ---
	jump_buffer -= delta
	coyote_timer -= delta

	if is_on_floor():
		coyote_timer = coyote_time

	# --- Input ---
	var move_input := Input.get_axis("Left", "Right")

	# --- Horizontal movement ---
	if in_water:
		velocity.x = move_toward(
			velocity.x,
			move_input * player_speed,
			water_accel * delta
		)
	else:
		if move_input != 0:
			velocity.x = move_toward(
				velocity.x,
				move_input * player_speed,
				land_accel * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0,
				land_friction * delta
			)

	# --- Gravity / Buoyancy ---
	if in_water:
		# Apply buoyancy
		velocity.y -= water_buoyancy * delta
		
		# Apply drag separately to X and Y for better control
		velocity.y *= exp(-water_drag * delta)
		velocity.x *= exp(-water_drag * 0.3 * delta)  # Less drag on horizontal
		
		# Clamp velocity in water
		velocity.x = clamp(velocity.x, -player_speed * 1.2, player_speed * 1.2)
		velocity.y = clamp(velocity.y, -max_velocity, max_velocity)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.y = clamp(velocity.y, -max_velocity, max_velocity)

	# --- Jump buffering ---
	if Input.is_action_just_pressed("Jump"):
		jump_buffer = jump_buffer_time

	# --- Jump execution ---
	if jump_buffer > 0 and (coyote_timer > 0 or in_water):
		velocity.y = -jump_force
		jump_buffer = 0
		coyote_timer = 0

	# --- Variable jump height ---
	if Input.is_action_just_released("Jump") and velocity.y < 0 and not in_water:
		velocity.y *= jump_cut_multiplier

	# --- Swim down ---
	if in_water and Input.is_action_pressed("Down"):
		velocity.y = move_toward(velocity.y, jump_force, water_accel * delta)

	# --- Attack ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_player_attack()

	move_and_slide()

func _player_switch_settings():
	if in_water:
		gravity = water_gravity
		max_velocity = max_velocity_water
		player_speed = player_water_speed
		jump_force = player_water_jump
	else:
		gravity = land_gravity
		max_velocity = max_velocity_air
		player_speed = player_land_speed
		jump_force = player_land_jump

func _player_attack() -> void:
	_shoot_bullet()
	#hitbox.monitoring = true
	#await get_tree().create_timer(0.2).timeout
	#hitbox.monitoring = false

func _on_hit_corrupter(corrupter):
	corrupter.take_damage(10)

func _shoot_bullet() -> void:
	if not can_shoot or not bullet_scene:
		return
	
	can_shoot = false
	
	# Get aim direction (mouse position)
	var aim_direction = (get_global_mouse_position() - global_position).normalized()
	last_aim_direction = aim_direction
	
	# Spawn bullet
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	
	# Position bullet slightly in front of player
	bullet.global_position = global_position + aim_direction * bullet_spawn_offset
	bullet.set_direction(aim_direction)
	
	# Cooldown
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
