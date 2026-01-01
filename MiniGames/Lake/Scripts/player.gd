extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_character: CharacterBody2D = $"."

# Player controls
@export var player_land_speed: float = 150
@export var player_water_speed: float = 100
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
@export var shoot_cooldown: float = 0.5
@export var bullet_spawn_offset: float = 20.0

# Health
@export var player_health: float = 100.0
@export var max_health: float = 100.0

# Oxygen System
@export var max_oxygen: float = 100.0
@export var oxygen_drain_rate: float = 5.0  # Oxygen lost per second underwater
@export var oxygen_refill_rate: float = 30.0  # Oxygen gained per second above water
@export var oxygen_damage_rate: float = 5.0  # Health lost per second when out of oxygen
@export var low_oxygen_threshold: float = 30.0  # When to show warning
@export var air_surface_offset: float = 20.0  # How far above water surface to breathe

var current_oxygen: float = 100.0
var is_drowning: bool = false
var water_surface_y: float = 0.0  # Track the water surface level
var is_at_surface: bool = false

var can_shoot: bool = true
var last_aim_direction: Vector2 = Vector2.RIGHT

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var jump_buffer := 0.0
var coyote_timer := 0.0
var damage_tween: Tween

# UI References
var oxygen_bar: ProgressBar = null
var oxygen_warning: Label = null

func _ready() -> void:
	add_to_group("player")
	var current_scene := get_tree().current_scene
	
	if has_node("Hitbox") and current_scene.name == "Bkt-lake-minigame":
		hitbox = $Hitbox
		hitbox.monitoring = false
		hitbox.connect("hit_corrupter", Callable(self, "_on_hit_corrupter"))
	
	# Setup oxygen UI
	_setup_oxygen_ui()
	
	# Initialize oxygen
	current_oxygen = max_oxygen
	
	# Find water surface level
	_find_water_surface()

func _physics_process(delta: float) -> void:
	_handle_oxygen(delta)
	_platformer_physics(delta)
	_update_oxygen_ui()
	_update_animation()
	
func _update_animation() -> void:
	if not animated_sprite_2d:
		return

	if velocity.x == 0.0:
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("swimming")

	# Flip sprite based on movement direction
	if velocity.x != 0:
		animated_sprite_2d.flip_h = velocity.x < 0

func _setup_oxygen_ui() -> void:
	# Create oxygen bar
	oxygen_bar = ProgressBar.new()
	add_child(oxygen_bar)
	
	# Position above player
	oxygen_bar.position = Vector2(-40, -30)
	oxygen_bar.custom_minimum_size.y = 2
	oxygen_bar.size = Vector2(80, 1)
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = current_oxygen
	oxygen_bar.show_percentage = false
	oxygen_bar.scale = Vector2(1, 0.25)

	# Style oxygen bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0, 0, 0, 1)
	oxygen_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.6, 1.0, 1)  # Blue for oxygen
	oxygen_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Create warning label
	oxygen_warning = Label.new()
	add_child(oxygen_warning)
	oxygen_warning.position = Vector2(-30, -75)
	oxygen_warning.text = "LOW AIR!"
	oxygen_warning.visible = false
	oxygen_warning.modulate = Color(1, 0.3, 0.3, 1)  # Red color
	
	# Add font size
	oxygen_warning.add_theme_font_size_override("font_size", 12)

func _handle_oxygen(delta: float) -> void:
	# Check if player's head is near the surface
	_check_surface_breathing()
	
	if in_water and not is_at_surface:
		# Drain oxygen when fully underwater (head below surface)
		current_oxygen -= oxygen_drain_rate * delta
		current_oxygen = max(0, current_oxygen)
		
		# Check if drowning
		if current_oxygen <= 0:
			if not is_drowning:
				is_drowning = true
				print("Player is drowning!")
			
			# Take damage while drowning
			take_damage(oxygen_damage_rate * delta)
		
		# Show oxygen bar when in water
		if oxygen_bar:
			oxygen_bar.visible = true
	else:
		# Refill oxygen when at surface or above water
		current_oxygen += oxygen_refill_rate * delta
		current_oxygen = min(max_oxygen, current_oxygen)
		
		# Stop drowning
		if is_drowning:
			is_drowning = false
			print("Player can breathe again!")
		
		# Hide oxygen bar when full and able to breathe
		if oxygen_bar and current_oxygen >= max_oxygen and not in_water:
			oxygen_bar.visible = false

func _update_oxygen_ui() -> void:
	if oxygen_bar:
		oxygen_bar.value = current_oxygen
		
		# Change color based on oxygen level
		var fill_style = StyleBoxFlat.new()
		if current_oxygen <= low_oxygen_threshold:
			# Red when low
			fill_style.bg_color = Color(1.0, 0.3, 0.3, 1)
			
			# Pulse effect
			var pulse = abs(sin(Time.get_ticks_msec() / 200.0))
			fill_style.bg_color.a = 0.7 + pulse * 0.3
		elif current_oxygen <= low_oxygen_threshold * 2:
			# Yellow when medium
			fill_style.bg_color = Color(1.0, 0.8, 0.2, 1)
		else:
			# Blue when good
			fill_style.bg_color = Color(0.2, 0.6, 1.0, 1)
		
		oxygen_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Show/hide warning
	if oxygen_warning:
		oxygen_warning.visible = current_oxygen <= low_oxygen_threshold and in_water and not is_at_surface
		
		# Pulse warning text
		if oxygen_warning.visible:
			var pulse = abs(sin(Time.get_ticks_msec() / 300.0))
			oxygen_warning.modulate.a = 0.5 + pulse * 0.5

func _find_water_surface() -> void:
	# Try to find water area to get surface level
	var water_area = get_tree().get_first_node_in_group("water")
	
	if water_area and water_area is Area2D:
		# Get the top of the water area
		if water_area.has_node("CollisionShape2D"):
			var collision_shape = water_area.get_node("CollisionShape2D")
			var shape = collision_shape.shape
			
			if shape is RectangleShape2D:
				# Get the top edge of the water rectangle
				water_surface_y = water_area.global_position.y - shape.size.y / 2
			elif shape is CircleShape2D:
				# Get the top of the circle
				water_surface_y = water_area.global_position.y - shape.radius
			
			print("Water surface found at Y: ", water_surface_y)
	else:
		print("Warning: Water area not found. Using default surface level.")
		water_surface_y = 0.0

func _check_surface_breathing() -> void:
	if not in_water:
		is_at_surface = false
		return
	
	# Check if player's head (top of sprite) is near the water surface
	var player_head_y = global_position.y - air_surface_offset
	
	# Player can breathe if their head is above or near the surface
	is_at_surface = player_head_y <= water_surface_y
	
	# Optional: Visual feedback when at surface
	if is_at_surface and current_oxygen < max_oxygen:
		# You could add a bubble particle effect here
		pass

func take_damage(amount: float) -> void:
	player_health -= amount
	player_health = max(0, player_health)
	
	# Optional: Add visual feedback
	if amount >= 1.0:  # Only print for significant damage (not drowning ticks)
		print("Player health: ", player_health)
	
	if player_health <= 0:
		_player_die()
	
	_flash_sprite()

func _flash_sprite() -> void:
	if damage_tween and damage_tween.is_running():
		return

	damage_tween = create_tween()
	damage_tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color(5, 5, 5),
		0.05
	)
	damage_tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color.WHITE,
		0.1
	)

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

	# --- Jump buffering (only on land) ---
	if Input.is_action_just_pressed("Jump") and not in_water:
		jump_buffer = jump_buffer_time

	# --- Jump execution (only on land) ---
	if jump_buffer > 0 and coyote_timer > 0 and not in_water:
		velocity.y = -jump_force
		jump_buffer = 0
		coyote_timer = 0

	# --- Variable jump height (only on land) ---
	if Input.is_action_just_released("Jump") and velocity.y < 0 and not in_water:
		velocity.y *= jump_cut_multiplier

	# --- Swimming up/down in water ---
	if in_water:
		# Swim up with W key
		if Input.is_action_pressed("Up"):
			velocity.y = move_toward(velocity.y, -jump_force, water_accel * delta)
		# Swim down with S key
		elif Input.is_action_pressed("Down"):
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
