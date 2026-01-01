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
var game_manager: Node = null
var is_dead: bool = false

var spawn_position: Vector2
var patrol_target: Vector2
var state: String = "patrol" # patrol, chase, attack, dead
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

	add_to_group("enemy")

	sprite.play("swim")

	# Find GameManager (NO AUTOLOAD)
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		push_warning("EvilFish: GameManager not found")

	# Setup timer if missing
	if not has_node("AttackTimer"):
		attack_timer = Timer.new()
		add_child(attack_timer)
		attack_timer.wait_time = 1.0
		attack_timer.one_shot = false
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	_setup_health_bar()
	_setup_hit_particles()
	_find_water_bounds()

	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dead or not player:
		return

	# Keep fish in water
	if water_bounds.has_area() and not water_bounds.has_point(global_position):
		var dir := (spawn_position - global_position).normalized()
		velocity = dir * speed
		state = "patrol"
		patrol_target = spawn_position

	if healthbar_timer > 0:
		healthbar_timer -= delta
		if healthbar_timer <= 0 and health_bar:
			health_bar.visible = false

	var dist := global_position.distance_to(player.global_position)

	match state:
		"patrol":
			_patrol_behavior()
			if dist < detection_range:
				state = "chase"

		"chase":
			_chase_behavior()
			if dist < attack_range:
				state = "attack"
				attack_timer.start()
			elif dist > detection_range * 1.5:
				state = "patrol"
				attack_timer.stop()
				patrol_target = _get_random_patrol_point()

		"attack":
			_attack_behavior()
			if dist > attack_range:
				state = "chase"
				attack_timer.stop()

	move_and_slide()
	_update_sprite_direction()

func _patrol_behavior() -> void:
	var dir := (patrol_target - global_position).normalized()
	velocity = dir * speed * 0.5
	if global_position.distance_to(patrol_target) < 10:
		patrol_target = _get_random_patrol_point()

func _chase_behavior() -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed

func _attack_behavior() -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed * 0.3

func _get_random_patrol_point() -> Vector2:
	for i in 10:
		var angle := randf() * TAU
		var dist := randf_range(patrol_radius * 0.5, patrol_radius)
		var point := spawn_position + Vector2(cos(angle), sin(angle)) * dist
		if _is_in_water_bounds(point):
			return point
	return spawn_position

func _on_attack_timer_timeout() -> void:
	if state == "attack" and player:
		if global_position.distance_to(player.global_position) < attack_range:
			if player.has_method("take_damage"):
				player.take_damage(damage)

func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount

	if health_bar:
		health_bar.value = health
		health_bar.visible = true
		healthbar_timer = healthbar_duration

	if hit_particles:
		hit_particles.emitting = true

	_flash_sprite()

	if health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true

	# ✅ REGISTER KILL
	if game_manager and game_manager.has_method("register_fish_kill"):
		game_manager.register_fish_kill()

	state = "dead"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	if attack_timer:
		attack_timer.stop()
	if health_bar:
		health_bar.visible = false

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await tween.finished

	queue_free()

func die_and_float() -> void:
	if is_dead:
		return
	is_dead = true

	state = "dead"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	if attack_timer:
		attack_timer.stop()
	if health_bar:
		health_bar.visible = false

	sprite.flip_v = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 200, 2.0)
	tween.tween_property(sprite, "modulate:a", 0.5, 2.0)

	await tween.finished
	queue_free()

func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	add_child(health_bar)
	health_bar.position = Vector2(-healthbar_size.x / 2, healthbar_offset.y)
	health_bar.size = healthbar_size
	health_bar.scale = Vector2(1, 0.25)
	health_bar.show_percentage = false
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	health_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2)
	health_bar.add_theme_stylebox_override("fill", fill)

func _setup_hit_particles() -> void:
	hit_particles = CPUParticles2D.new()
	add_child(hit_particles)
	hit_particles.amount = 12
	hit_particles.lifetime = 0.5
	hit_particles.one_shot = true
	hit_particles.explosiveness = 0.9
	hit_particles.scale_amount_min = 3
	hit_particles.scale_amount_max = 6
	hit_particles.direction = Vector2.UP
	hit_particles.spread = 180
	hit_particles.initial_velocity_min = 60
	hit_particles.initial_velocity_max = 120
	hit_particles.gravity = Vector2(0, 150)
	hit_particles.color = Color(1, 0.2, 0.2)

func _flash_sprite() -> void:
	sprite.modulate = Color(5, 5, 5)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		sprite.modulate = Color.WHITE

func _find_water_bounds() -> void:
	var water := get_tree().get_first_node_in_group("water")
	if water and water.has_node("CollisionShape2D"):
		var shape: Shape2D = water.get_node("CollisionShape2D").shape
		if shape is RectangleShape2D:
			water_bounds = Rect2(water.global_position - shape.size / 2, shape.size)
	else:
		water_bounds = Rect2(
			spawn_position - Vector2(patrol_radius * 2, patrol_radius * 2),
			Vector2(patrol_radius * 4, patrol_radius * 4)
		)

func _is_in_water_bounds(point: Vector2) -> bool:
	return not water_bounds.has_area() or water_bounds.has_point(point)

func _update_sprite_direction() -> void:
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false
