extends CharacterBody2D

@export var speed: float = 80.0
@export var detection_range: float = 300.0
@export var attack_range: float = 50.0
@export var patrol_radius: float = 100.0
@export var damage: float = 10.0
@export var health: float = 30.0
@export var max_health: float = 30.0
@export var healthbar_duration: float = 3.0
@export var healthbar_size: Vector2 = Vector2(40, 6)
@export var healthbar_offset: Vector2 = Vector2(0, -35)

var player: Node2D = null
var spawn_position: Vector2
var patrol_target: Vector2
var state: String = "patrol"  # patrol, chase, attack
var healthbar_timer: float = 0.0
var health_bar: ProgressBar = null
var hit_particles: CPUParticles2D = null
var water_area: Area2D = null
var water_bounds: Rect2 = Rect2()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	spawn_position = global_position
	patrol_target = _get_random_patrol_point()
	
	collision_layer = 4
	collision_mask = 1
	
	if not has_node("AttackTimer"):
		attack_timer = Timer.new()
		add_child(attack_timer)
		attack_timer.wait_time = 1
		attack_timer.one_shot = false
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Setup health bar
	_setup_health_bar()
	
	# Setup hit particles
	_setup_hit_particles()
	
	# Find water area bounds
	_find_water_bounds()
	
	# Find player
	player = get_tree().get_first_node_in_group("player")

func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	add_child(health_bar)
	
	# Position above fish - auto-center based on size
	health_bar.position = Vector2(-healthbar_size.x / 2, healthbar_offset.y)
	health_bar.size = healthbar_size
	health_bar.show_percentage = false
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false
	
	# Style the health bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0, 0, 0, 1)
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 0.2, 1)
	health_bar.add_theme_stylebox_override("fill", fill_style)

func _setup_hit_particles() -> void:
	hit_particles = CPUParticles2D.new()
	add_child(hit_particles)
	
	hit_particles.emitting = false
	hit_particles.amount = 12
	hit_particles.lifetime = 0.5
	hit_particles.one_shot = true
	hit_particles.explosiveness = 0.9
	
	# Particle appearance
	hit_particles.scale_amount_min = 3.0
	hit_particles.scale_amount_max = 6.0
	
	# Movement
	hit_particles.direction = Vector2(0, -1)
	hit_particles.spread = 180
	hit_particles.initial_velocity_min = 60.0
	hit_particles.initial_velocity_max = 120.0
	hit_particles.gravity = Vector2(0, 150)
	
	# Color (red blood-like effect)
	hit_particles.color = Color(1, 0.2, 0.2, 1)

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# Keep fish within water bounds
	if water_bounds.has_area() and not water_bounds.has_point(global_position):
		# Push fish back towards spawn if outside bounds
		var direction_to_spawn = (spawn_position - global_position).normalized()
		velocity = direction_to_spawn * speed
		state = "patrol"
		patrol_target = spawn_position
	
	# Update healthbar visibility timer
	if healthbar_timer > 0:
		healthbar_timer -= delta
		if healthbar_timer <= 0 and health_bar:
			health_bar.visible = false
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State machine
	match state:
		"patrol":
			_patrol_behavior(delta)
			if distance_to_player < detection_range:
				state = "chase"
		
		"chase":
			_chase_behavior(delta)
			if distance_to_player < attack_range:
				state = "attack"
				attack_timer.start()
			elif distance_to_player > detection_range * 1.5:
				state = "patrol"
				patrol_target = _get_random_patrol_point()
		
		"attack":
			_attack_behavior(delta)
			if distance_to_player > attack_range:
				state = "chase"
				attack_timer.stop()
	
	move_and_slide()
	_update_sprite_direction()

func _patrol_behavior(_delta: float) -> void:
	var direction = (patrol_target - global_position).normalized()
	velocity = direction * speed * 0.5
	
	if global_position.distance_to(patrol_target) < 10:
		patrol_target = _get_random_patrol_point()

func _chase_behavior(_delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed

func _attack_behavior(_delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed * 0.3

func _get_random_patrol_point() -> Vector2:
	var point: Vector2
	var attempts = 10
	
	for i in attempts:
		var angle = randf() * TAU
		var distance = randf_range(patrol_radius * 0.5, patrol_radius)
		point = spawn_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Check if point is within water bounds
		if _is_in_water_bounds(point):
			return point
	
	# Fallback: return spawn position if no valid point found
	return spawn_position

func _find_water_bounds() -> void:
	# Try to find water area by checking parent or nearby Area2D nodes
	var parent = get_parent()
	
	# Check if spawned by a water spawner
	for child in parent.get_children():
		if child is Area2D and child.has_method("_spawn_fish"):
			water_area = child
			break
	
	# If still not found, look for any Area2D in the scene
	if not water_area:
		water_area = get_tree().get_first_node_in_group("water")
	
	# Calculate bounds from the water area's collision shape
	if water_area and water_area.has_node("CollisionShape2D"):
		var collision_shape = water_area.get_node("CollisionShape2D")
		var shape = collision_shape.shape
		
		if shape is RectangleShape2D:
			var rect_size = shape.size
			water_bounds = Rect2(
				water_area.global_position - rect_size / 2,
				rect_size
			)
		elif shape is CircleShape2D:
			var radius = shape.radius
			water_bounds = Rect2(
				water_area.global_position - Vector2(radius, radius),
				Vector2(radius * 2, radius * 2)
			)
	else:
		# Fallback: create bounds around spawn position
		water_bounds = Rect2(
			spawn_position - Vector2(patrol_radius * 2, patrol_radius * 2),
			Vector2(patrol_radius * 4, patrol_radius * 4)
		)

func _is_in_water_bounds(point: Vector2) -> bool:
	if water_bounds.has_area():
		return water_bounds.has_point(point)
	return true  # If no bounds set, allow anywhere

func _update_sprite_direction() -> void:
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

func _on_attack_timer_timeout() -> void:
	if state == "attack" and player:
		var distance = global_position.distance_to(player.global_position)
		if distance < attack_range:
			_deal_damage_to_player()

func _deal_damage_to_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage)

func take_damage(amount: float) -> void:
	health -= amount
	
	# Update and show health bar
	if health_bar:
		health_bar.value = health
		health_bar.visible = true
		healthbar_timer = healthbar_duration
	
	# Play hit effect
	if hit_particles:
		hit_particles.emitting = true
	
	# Flash sprite white
	_flash_sprite()
	
	# Die if health depleted
	if health <= 0:
		_die()

func _flash_sprite() -> void:
	# Flash bright
	sprite.modulate = Color(5, 5, 5, 1)
	
	# Return to normal
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		sprite.modulate = Color(1, 1, 1, 1)

func _die() -> void:
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()
