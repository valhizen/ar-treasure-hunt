extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var main_character: CharacterBody2D = $"."

# Player controls
@export var player_land_speed: float = 150
@export var player_water_speed: float = 75
var player_speed = player_land_speed

# Platformer states
@export var just_entered_water: bool = false
@export var just_exited_water: bool = false
@export var platformer: bool = false
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

@export var player_health: float = 100.0

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var jump_buffer := 0.0
var coyote_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	animated_sprite_2d.play("idle_down")
	var current_scene := get_tree().current_scene
	
	if has_node("Hitbox") and current_scene.name == "Bkt-lake-minigame":
		hitbox = $Hitbox
		hitbox.monitoring = false
		hitbox.connect("hit_corrupter", Callable(self, "_on_hit_corrupter"))

func _physics_process(delta: float) -> void:
	if platformer:
		_platformer_physics(delta)
	else:
		_top_down_physics(delta)

func _input(event: InputEvent) -> void:
	if platformer:
		_platformer_input(event)
	else:
		_top_down_input(event)

#--------------------
#  Platformer Logics
#--------------------

func take_damage(amount: float) -> void:
	player_health -= amount
	print("Player took damage! Health: ", player_health)
	# Add visual feedback, death check, etc.
	if player_health <= 0:
		_player_die()

func _player_die() -> void:
	# Handle player death
	pass

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

func _platformer_input(event: InputEvent) -> void:
	pass

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
	hitbox.monitoring = true
	await get_tree().create_timer(0.2).timeout
	hitbox.monitoring = false

func _on_hit_corrupter(corrupter):
	corrupter.take_damage(10)

#--------------------
#   Top Down Logics
#--------------------

func _top_down_physics(_delta: float) -> void:
	var input_direction = Input.get_vector("Left", "Right", "Up", "Down")
	velocity = input_direction * player_speed
	update_animation(input_direction)
	move_and_slide()

func _top_down_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		look_at_mouse()

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

func look_at_mouse():
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	# Determine which direction to face
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite_2d.play("idle_right")
		else:
			animated_sprite_2d.play("idle_left")
	else:
		if direction.y > 0:
			animated_sprite_2d.play("idle_down")
		else:
			animated_sprite_2d.play("idle_up")

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		return
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return
