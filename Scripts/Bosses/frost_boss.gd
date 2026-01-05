extends CharacterBody2D
class_name FrostBoss

# === BOSS STATS ===
@export_category("Stats")
@export var max_health: float = 500.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 25.0

# === HAIL STORM (INSTANT KILL) ===
@export_category("Hail Storm")
@export var hail_interval: float = 8.0  ## Seconds between hail storms
@export var hail_warning_time: float = 1.5  ## Warning before hail falls
@export var hail_count: int = 12  ## Number of hailstones per storm
@export var hail_fall_speed: float = 600.0
@export var hail_spread: float = 400.0  ## Horizontal spread area
@export var hail_is_instant_kill: bool = true

# === ICE SPIKE ATTACK ===
@export_category("Ice Spikes")
@export var spike_interval: float = 3.0
@export var spike_warning_time: float = 0.8
@export var spike_damage: float = 30.0
@export var spike_count: int = 5

# === CHARGE ATTACK ===
@export_category("Charge Attack")
@export var charge_speed: float = 350.0
@export var charge_damage: float = 40.0
@export var charge_interval: float = 6.0

# === PHASES ===
@export_category("Phases")
@export var phase2_threshold: float = 0.6  ## 60% health
@export var phase3_threshold: float = 0.3  ## 30% health

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox

# State
var current_health: float
var current_phase: int = 1
var player: Node2D = null
var is_attacking: bool = false
var is_charging: bool = false
var facing_left: bool = true

# Timers
var hail_timer: float = 0.0
var spike_timer: float = 0.0
var charge_timer: float = 0.0

# Signals
signal health_changed(current: float, maximum: float)
signal boss_defeated
signal phase_changed(new_phase: int)

# Preloads
var hailstone_scene: PackedScene
var ice_spike_scene: PackedScene
var warning_indicator_scene: PackedScene


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	current_health = max_health
	
	# Create attack scenes dynamically
	_create_attack_scenes()
	
	# Setup collision
	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	if hitbox:
		hitbox.add_to_group("enemy_attack")
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		_disable_hitbox()
	
	# Find player
	await get_tree().process_frame
	_find_player()
	
	health_changed.emit(current_health, max_health)
	
	# Start attack timers with offset so attacks don't all happen at once
	hail_timer = hail_interval * 0.5
	spike_timer = spike_interval
	charge_timer = charge_interval * 0.3


func _create_attack_scenes() -> void:
	# We'll create these dynamically in the attack functions
	pass


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _physics_process(delta: float) -> void:
	if not player or current_health <= 0:
		return
	
	_update_timers(delta)
	_update_facing()
	
	if not is_attacking and not is_charging:
		_move_towards_player(delta)


func _update_timers(delta: float) -> void:
	hail_timer -= delta
	spike_timer -= delta
	charge_timer -= delta
	
	# Check for attacks (priority: hail > charge > spikes)
	if hail_timer <= 0 and not is_attacking:
		hail_timer = hail_interval / current_phase  # Faster in later phases
		_start_hail_storm()
	elif charge_timer <= 0 and not is_attacking and current_phase >= 2:
		charge_timer = charge_interval / (current_phase * 0.5)
		_start_charge_attack()
	elif spike_timer <= 0 and not is_attacking:
		spike_timer = spike_interval / current_phase
		_start_ice_spikes()


func _update_facing() -> void:
	if player:
		facing_left = player.global_position.x < global_position.x
		if animated_sprite:
			animated_sprite.flip_h = not facing_left


func _move_towards_player(delta: float) -> void:
	if not player:
		return
	
	var direction = sign(player.global_position.x - global_position.x)
	var distance = abs(player.global_position.x - global_position.x)
	
	# Keep some distance from player
	var preferred_distance = 100.0
	if distance > preferred_distance + 20:
		velocity.x = direction * move_speed
	elif distance < preferred_distance - 20:
		velocity.x = -direction * move_speed * 0.5
	else:
		velocity.x = 0
	
	velocity.y = 0  # Assuming boss stays on ground level
	move_and_slide()
	
	# Animation
	if animated_sprite and abs(velocity.x) > 10:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	elif animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")


# ===================
# HAIL STORM ATTACK
# ===================
func _start_hail_storm() -> void:
	is_attacking = true
	
	# Boss animation/telegraph
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
	
	# Screen shake warning
	_trigger_screen_shake(0.3)
	
	# Spawn warning indicators
	var warnings: Array[Node2D] = []
	var hail_positions: Array[Vector2] = []
	
	for i in range(hail_count + (current_phase * 3)):  # More hail in later phases
		var x_pos = player.global_position.x + randf_range(-hail_spread, hail_spread)
		var y_pos = player.global_position.y - 300  # Spawn above screen
		hail_positions.append(Vector2(x_pos, y_pos))
		
		# Create warning indicator on ground
		var warning = _create_warning_indicator(Vector2(x_pos, player.global_position.y))
		warnings.append(warning)
	
	# Wait for warning time
	await get_tree().create_timer(hail_warning_time).timeout
	
	# Remove warnings and spawn hail
	for warning in warnings:
		if is_instance_valid(warning):
			warning.queue_free()
	
	# Spawn hailstones
	for pos in hail_positions:
		_spawn_hailstone(pos)
		await get_tree().create_timer(0.05).timeout  # Slight delay between each
	
	await get_tree().create_timer(1.0).timeout
	is_attacking = false


func _create_warning_indicator(pos: Vector2) -> Node2D:
	# Create a simple warning circle
	var warning = Node2D.new()
	warning.global_position = pos
	
	var sprite = Sprite2D.new()
	# Create a simple circle texture programmatically
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 0.5))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.modulate = Color(1, 0.2, 0.2, 0.7)
	
	warning.add_child(sprite)
	get_tree().current_scene.add_child(warning)
	
	# Pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.3, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.8, 0.2)
	
	return warning


func _spawn_hailstone(pos: Vector2) -> void:
	var hail = Area2D.new()
	hail.global_position = pos
	hail.add_to_group("boss_attack")
	
	# Visual
	var sprite = Sprite2D.new()
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.7, 0.9, 1.0, 1.0))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	hail.add_child(sprite)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	hail.add_child(collision)
	
	hail.monitoring = true
	hail.monitorable = true
	hail.collision_layer = 0
	hail.collision_mask = 2  # Player layer
	
	get_tree().current_scene.add_child(hail)
	
	# Movement and collision handling
	hail.area_entered.connect(func(area):
		if area.is_in_group("player_hurtbox"):
			var p = get_tree().get_nodes_in_group("player")
			if p.size() > 0:
				if hail_is_instant_kill:
					if p[0].has_method("instant_kill"):
						p[0].instant_kill()
					elif p[0].has_method("take_damage"):
						p[0].take_damage(9999)
				else:
					if p[0].has_method("take_damage"):
						p[0].take_damage(50)
			hail.queue_free()
	)
	
	# Fall animation
	var target_y = pos.y + 400
	var tween = create_tween()
	tween.tween_property(hail, "global_position:y", target_y, 400.0 / hail_fall_speed)
	tween.tween_callback(hail.queue_free)


# ===================
# ICE SPIKE ATTACK
# ===================
func _start_ice_spikes() -> void:
	is_attacking = true
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.play("attack")
	
	var spike_positions: Array[Vector2] = []
	var warnings: Array[Node2D] = []
	
	# Spikes emerge from ground around player
	var base_x = player.global_position.x
	var ground_y = player.global_position.y + 20  # Adjust based on your ground level
	
	var total_spikes = spike_count + (current_phase - 1) * 2
	for i in range(total_spikes):
		var offset = (i - total_spikes / 2.0) * 50
		var spike_pos = Vector2(base_x + offset, ground_y)
		spike_positions.append(spike_pos)
		
		var warning = _create_ground_warning(spike_pos)
		warnings.append(warning)
	
	await get_tree().create_timer(spike_warning_time).timeout
	
	for warning in warnings:
		if is_instance_valid(warning):
			warning.queue_free()
	
	# Spawn spikes with slight delay for dramatic effect
	for pos in spike_positions:
		_spawn_ice_spike(pos)
		await get_tree().create_timer(0.08).timeout
	
	await get_tree().create_timer(0.5).timeout
	is_attacking = false


func _create_ground_warning(pos: Vector2) -> Node2D:
	var warning = Node2D.new()
	warning.global_position = pos
	
	var sprite = Sprite2D.new()
	var img = Image.create(40, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.8, 1.0, 0.6))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	
	warning.add_child(sprite)
	get_tree().current_scene.add_child(warning)
	
	# Pulsing
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.3, 0.15)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.15)
	
	return warning


func _spawn_ice_spike(pos: Vector2) -> void:
	var spike = Area2D.new()
	spike.global_position = pos + Vector2(0, 30)  # Start below ground
	spike.add_to_group("boss_attack")
	
	# Visual (tall spike)
	var sprite = Sprite2D.new()
	var img = Image.create(16, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.85, 1.0, 1.0))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.offset.y = -32  # Pivot at bottom
	spike.add_child(sprite)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 64)
	collision.shape = shape
	collision.position.y = -32
	spike.add_child(collision)
	
	spike.monitoring = true
	spike.monitorable = true
	spike.collision_layer = 0
	spike.collision_mask = 2
	
	get_tree().current_scene.add_child(spike)
	
	spike.area_entered.connect(func(area):
		if area.is_in_group("player_hurtbox"):
			var p = get_tree().get_nodes_in_group("player")
			if p.size() > 0 and p[0].has_method("take_damage"):
				var kb_dir = Vector2(sign(p[0].global_position.x - spike.global_position.x), -1).normalized()
				p[0].take_damage(spike_damage * current_phase, kb_dir)
	)
	
	# Emerge animation
	var tween = create_tween()
	tween.tween_property(spike, "global_position:y", pos.y - 32, 0.15).set_ease(Tween.EASE_OUT)
	
	# Retract after delay
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(spike):
		var retract_tween = create_tween()
		retract_tween.tween_property(spike, "global_position:y", pos.y + 30, 0.3)
		retract_tween.tween_callback(spike.queue_free)


# ===================
# CHARGE ATTACK
# ===================
func _start_charge_attack() -> void:
	is_attacking = true
	is_charging = true
	
	# Telegraph
	if animated_sprite and animated_sprite.sprite_frames.has_animation("charge_windup"):
		animated_sprite.play("charge_windup")
	
	# Brief pause before charge
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	
	if not is_instance_valid(player):
		is_attacking = false
		is_charging = false
		return
	
	# Enable hitbox
	_enable_hitbox()
	
	# Charge towards player's position
	var charge_direction = sign(player.global_position.x - global_position.x)
	var charge_target = global_position.x + (charge_direction * 500)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("charge"):
		animated_sprite.play("charge")
	
	_trigger_screen_shake(0.2)
	
	# Perform charge
	var charge_tween = create_tween()
	charge_tween.tween_property(self, "global_position:x", charge_target, 0.6).set_ease(Tween.EASE_IN)
	
	await charge_tween.finished
	
	_disable_hitbox()
	
	# Recovery time
	await get_tree().create_timer(0.8).timeout
	
	is_attacking = false
	is_charging = false


# ===================
# DAMAGE & PHASES
# ===================
func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = maxf(current_health, 0)
	health_changed.emit(current_health, max_health)
	
	# Flash effect
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		animated_sprite.modulate = Color.WHITE
	
	# Check phase transitions
	var health_percent = current_health / max_health
	
	if health_percent <= phase3_threshold and current_phase < 3:
		_enter_phase(3)
	elif health_percent <= phase2_threshold and current_phase < 2:
		_enter_phase(2)
	
	# Check death
	if current_health <= 0:
		_die()


func _enter_phase(phase: int) -> void:
	current_phase = phase
	phase_changed.emit(phase)
	
	# Visual feedback
	_trigger_screen_shake(0.5)
	
	# Brief invulnerability during transition
	if animated_sprite and animated_sprite.sprite_frames.has_animation("roar"):
		animated_sprite.play("roar")
	
	# Immediate attack after phase change
	match phase:
		2:
			move_speed *= 1.3
			await get_tree().create_timer(0.5).timeout
			_start_charge_attack()
		3:
			move_speed *= 1.2
			hail_count += 5
			await get_tree().create_timer(0.3).timeout
			_start_hail_storm()


func _die() -> void:
	is_attacking = false
	boss_defeated.emit()
	
	# Death animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	
	queue_free()


# ===================
# COLLISION HANDLING
# ===================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_method("attack_damage"):
			take_damage(players[0].attack_damage)
		else:
			take_damage(10)  # Default damage


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0 and p[0].has_method("take_damage"):
			var kb_dir = Vector2(sign(p[0].global_position.x - global_position.x), 0)
			p[0].take_damage(charge_damage, kb_dir)


func _enable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true


func _disable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false


func _trigger_screen_shake(intensity: float) -> void:
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam.has_method("shake"):
			cam.shake(intensity)
		elif cam.has_method("damage_shake"):
			cam.damage_shake()
