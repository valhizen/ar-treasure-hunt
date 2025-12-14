extends RigidBody2D

# States
@export var on_ground := false
@export var in_water: bool = false

@export var water_gravity_scale: float = 0.05
@export var land_gravity_scale: float = 1

@export var water_up_force: float = 500
@export var water_down_force: float = 500
@export var water_swim_speed: float = 200

@export var move_speed := 250.0
@export var acceleration := 12.0
@export var deceleration := 8.0
@export var jump_force := 500.0
@export var gravity_scale_land := 4.0

@export var coyote_time := 0.15
@export var jump_buffer_time := 0.15

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if in_water:
		_handle_water_physics(delta)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if in_water:
		return
	
	_handle_ground_check(state)
	_handle_jump_logic(state)
	_handle_horizontal(state)
	
func _handle_water_physics(delta: float) -> void:
	gravity_scale = water_gravity_scale
	
	if Input.is_key_pressed(KEY_SPACE):
		linear_velocity.y -= water_up_force * delta;
	elif Input.is_key_pressed(KEY_SHIFT):
		linear_velocity.y += water_down_force * delta;
	
	if Input.is_key_pressed(KEY_A):
		linear_velocity.x = lerp(linear_velocity.x, -water_swim_speed, 0.1)
	elif Input.is_key_pressed(KEY_D):
		linear_velocity.x = lerp(linear_velocity.x, water_swim_speed, 0.1)
	else:
		linear_velocity.x = lerp(linear_velocity.x, 0.0, 0.05)

func _handle_ground_check(state: PhysicsDirectBodyState2D) -> void:
	on_ground = false
	for i in range(state.get_contact_count()):
		var contact_normal = state.get_contact_local_normal(i)
		var collider = state.get_contact_collider_object(i)
		# Check if it's a TileMap and the surface is ground-like
		if collider is TileMapLayer and contact_normal.dot(Vector2.UP) > 0.6:
			on_ground = true
			break
	
	# Update coyote timer
	if on_ground:
		coyote_timer = coyote_time
	else:
		coyote_timer -= state.step
		if coyote_timer <= 0:
			coyote_timer = 0

func _handle_jump_logic(state: PhysicsDirectBodyState2D) -> void:
	# Track jump press
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= state.step
		if jump_buffer_timer <= 0:
			jump_buffer_timer = 0

	# Perform jump
	# print(jump_buffer_timer, coyote_timer)
	if jump_buffer_timer > 0 and coyote_timer > 0:
		var v = state.linear_velocity
		v.y = -jump_force
		state.linear_velocity = v

		# reset timers
		jump_buffer_timer = 0
		coyote_timer = 0

func _handle_horizontal(state: PhysicsDirectBodyState2D) -> void:
	var target := 0.0
	if Input.is_action_pressed("Left"):
		target = -move_speed
	elif Input.is_action_pressed("Right"):
		target = move_speed
	
	# Check if we're blocked by a wall
	var is_blocked = false
	if target != 0:
		for i in range(state.get_contact_count()):
			var contact_normal = state.get_contact_local_normal(i)
			# If pushing left into a right-facing wall (normal points right)
			# or pushing right into a left-facing wall (normal points left)
			if (target < 0 and contact_normal.x > 0.7) or \
			   (target > 0 and contact_normal.x < -0.7):
				is_blocked = true
				break
	
	var v = state.linear_velocity
	if !is_blocked:
		v.x = lerp(v.x, target, acceleration * state.step) if target != 0 \
			else lerp(v.x, 0.0, deceleration * state.step)
	else:
		# Stop trying to move into the wall
		v.x = lerp(v.x, 0.0, deceleration * state.step)
	
	state.linear_velocity = v
