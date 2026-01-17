extends CharacterBody2D
class_name MainCharacter

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder

@export var debug := true
# === MODE ===
@export_category("Mode")
@export_enum("TopDown", "Platformer") var character_mode: int = 0
@export var enable_combat: bool = false

# === MOVEMENT ===
@export_category("Movement")
@export var player_speed: float = 150.0
@export var sprint_multiplier: float = 1.6
@export var sprint_stamina_cost: float = 20.0  ## Stamina per second while sprinting

# === PLATFORMER PHYSICS ===
@export_category("Platformer Physics")
@export var gravity: float = 980.0
@export var jump_force: float = 350.0
@export var max_fall_speed: float = 600.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# === COMBAT ===
@export_category("Combat")
@export var max_health: float = 100.0
@export var hitbox_offset: float = 25.0
@export var attack_damage: float = 10.0

# === STAMINA ===
@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 25.0  ## Per second
@export var stamina_regen_delay: float = 0.8  ## Seconds before regen starts
@export var attack_stamina_cost: float = 20.0
@export var jump_stamina_cost: float = 15.0
@export var dodge_stamina_cost: float = 25.0

# === DODGE/DASH ===
@export_category("Dodge")
@export var enable_dodge: bool = true
@export var dodge_speed: float = 400.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.5
@export var dodge_invincibility: bool = true

@export_category("Spacing")
## Minimum distance from boss (prevents clipping)
@export var min_boss_distance: float = 60.0

# Nodes
var hitbox: Area2D = null
var hurtbox: Area2D = null

# State
var facing_direction: String = "right"
var is_attacking: bool = false
var current_health: float
var is_invulnerable: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

# Stamina state
var current_stamina: float
var stamina_regen_timer: float = 0.0
var is_stamina_exhausted: bool = false  ## True when stamina hits 0, blocks actions until partial recovery

# Sprint state
var is_sprinting: bool = false

# Dodge state
var is_dodging: bool = false
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0

# Platformer state
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal player_died

var is_platformer: bool:
	get: return character_mode == 1


func _ready() -> void:
	if debug && GlobalData.DEBUG:
		player_speed = 500
		
		var cam := $Camera2D
		if cam:
			cam.zoom /= 3

	add_to_group("player")
	current_health = max_health
	current_stamina = max_stamina
	
	if enable_combat:
		_setup_hitbox()
		_setup_hurtbox()
	
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.play("idle_right" if is_platformer else "idle_down")
	
	await get_tree().process_frame
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)


func _setup_hitbox() -> void:
	if has_node("HitBox"):
		hitbox = $HitBox
		hitbox.add_to_group("player_attack")
		_disable_hitbox()


func _setup_hurtbox() -> void:
	if has_node("HurtBox"):
		hurtbox = $HurtBox
		hurtbox.add_to_group("player_hurtbox")
		hurtbox.monitoring = true
		hurtbox.monitorable = true


func _disable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		hitbox.set_deferred("monitoring", false)


func _enable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true


func _physics_process(delta: float) -> void:
	# Update timers
	_update_stamina(delta)
	_update_dodge(delta)
	
	# Anti-clipping with boss
	_handle_boss_spacing()
	
	if is_dodging:
		_process_dodge(delta)
	elif is_platformer:
		_platformer_movement(delta)
	else:
		_topdown_movement(delta)


func _update_stamina(delta: float) -> void:
	# Reduce regen delay timer
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
	
	# Check if exhausted state should end (recover to 30%)
	if is_stamina_exhausted and current_stamina >= max_stamina * 0.3:
		is_stamina_exhausted = false
	
	# Regenerate stamina
	if stamina_regen_timer <= 0 and current_stamina < max_stamina and not is_sprinting:
		current_stamina = minf(current_stamina + stamina_regen_rate * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)


func _consume_stamina(amount: float) -> bool:
	if is_stamina_exhausted:
		return false
	
	if current_stamina < amount:
		return false
	
	current_stamina -= amount
	stamina_regen_timer = stamina_regen_delay
	stamina_changed.emit(current_stamina, max_stamina)
	
	if current_stamina <= 0:
		current_stamina = 0
		is_stamina_exhausted = true
		# Visual feedback for exhaustion
		_show_exhausted_effect()
	
	return true


func _show_exhausted_effect() -> void:
	# Flash to indicate exhaustion
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(0.5, 0.5, 1.0), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.2)


func _update_dodge(delta: float) -> void:
	if dodge_cooldown_timer > 0:
		dodge_cooldown_timer -= delta


func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	
	if dodge_timer <= 0:
		is_dodging = false
		if dodge_invincibility:
			is_invulnerable = false
		return
	
	velocity = dodge_direction * dodge_speed
	move_and_slide()


func _handle_boss_spacing() -> void:
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		
		var dist = abs(boss.global_position.x - global_position.x)
		if dist < min_boss_distance and dist > 0:
			var push_dir = sign(global_position.x - boss.global_position.x)
			var push_strength = (min_boss_distance - dist) * 2
			global_position.x += push_dir * push_strength * get_physics_process_delta_time() * 60


func _input(event: InputEvent) -> void:
	# Dodge input
	
	if not enable_combat or is_attacking or is_dodging:
		return
	
	if event.is_action_pressed("attack"):
		_attack(1)

	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			_attack(1)



func _try_dodge() -> void:
	if dodge_cooldown_timer > 0 or is_dodging:
		return
	
	if not _consume_stamina(dodge_stamina_cost):
		return
	
	is_dodging = true
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	
	if dodge_invincibility:
		is_invulnerable = true
	
	# Get dodge direction from input or facing direction
	var input_dir: Vector2
	if is_platformer:
		input_dir = Vector2(Input.get_axis("Left", "Right"), 0)
	else:
		input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0:
		dodge_direction = input_dir.normalized()
	else:
		# Dodge in facing direction
		match facing_direction:
			"right": dodge_direction = Vector2.RIGHT
			"left": dodge_direction = Vector2.LEFT
			"up": dodge_direction = Vector2.UP
			"down": dodge_direction = Vector2.DOWN
	
	# Visual effect - ghost trail (no dodge animation available)
	_spawn_dodge_ghost()


func _spawn_dodge_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = animated_sprite_2d.sprite_frames.get_frame_texture(
		animated_sprite_2d.animation, 
		animated_sprite_2d.frame
	)
	ghost.global_position = global_position
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.6)
	get_parent().add_child(ghost)
	
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


# === TOP-DOWN ===
func _topdown_movement(delta: float) -> void:
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
		move_and_slide()
		return
	
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var input = Input.get_vector("Left", "Right", "Up", "Down")
	
	# Sprint handling (uses run animation since no sprint animation exists)
	var speed = player_speed
	is_sprinting = false

	
	velocity = input * speed
	
	if input.length() > 0:
		if abs(input.x) > abs(input.y):
			facing_direction = "right" if input.x > 0 else "left"
		else:
			facing_direction = "down" if input.y > 0 else "up"
		
		# Use run animation (no sprint animation available)
		animated_sprite_2d.play("run_" + facing_direction)
	else:
		if "run" in animated_sprite_2d.animation:
			animated_sprite_2d.play("idle_" + facing_direction)
	
	move_and_slide()


# === PLATFORMER ===
func _platformer_movement(delta: float) -> void:
	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)
	
	# --- COYOTE TIME ---
	if is_on_floor():
		coyote_timer = coyote_time
		was_on_floor = true
	else:
		coyote_timer -= delta
	
	# --- JUMP BUFFER ---
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	# --- JUMPING (costs stamina) ---
	if jump_buffer_timer > 0 and coyote_timer > 0:
		if _consume_stamina(jump_stamina_cost):
			velocity.y = -jump_force
			jump_buffer_timer = 0
			coyote_timer = 0
		else:
			jump_buffer_timer = 0  # Clear buffer if no stamina
	
	# --- VARIABLE JUMP HEIGHT ---
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= 0.5
	
	# --- SPRINT HANDLING ---
	var speed = player_speed
	is_sprinting = false
	var h_input = Input.get_axis("Left", "Right")
	
	if Input.is_action_pressed("sprint") and abs(h_input) > 0 and not is_stamina_exhausted:
		if current_stamina > 0:
			is_sprinting = true
			speed *= sprint_multiplier
			current_stamina -= sprint_stamina_cost * delta
			stamina_regen_timer = stamina_regen_delay
			stamina_changed.emit(current_stamina, max_stamina)
			
			if current_stamina <= 0:
				current_stamina = 0
				is_stamina_exhausted = true
				_show_exhausted_effect()
	
	# --- KNOCKBACK ---
	if knockback_velocity.length() > 10:
		velocity.x = knockback_velocity.x
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
	elif not is_attacking:
		# --- HORIZONTAL MOVEMENT ---
		if Input.is_action_pressed("Left"):
			velocity.x = -speed
			facing_direction = "left"
		elif Input.is_action_pressed("Right"):
			velocity.x = speed
			facing_direction = "right"
		else:
			velocity.x = move_toward(velocity.x, 0, player_speed * 0.2)
	else:
		velocity.x = move_toward(velocity.x, 0, player_speed * 0.3)
	
	move_and_slide()
	
	# --- ANIMATIONS ---
	_update_platformer_animation()


func _update_platformer_animation() -> void:
	if is_attacking:
		return
	
	# No jump/fall animations available, use run when moving, idle when not
	if abs(velocity.x) > 10:
		# Use run animation (no sprint animation available)
		animated_sprite_2d.play("run_" + facing_direction)
	else:
		animated_sprite_2d.play("idle_" + facing_direction)


func _play_anim(type: String) -> void:
	if is_attacking:
		return
	var anim = type + "_" + facing_direction
	if animated_sprite_2d.sprite_frames.has_animation(anim):
		if animated_sprite_2d.animation != anim:
			animated_sprite_2d.play(anim)
	else:
		var fallback = "idle_" + facing_direction
		if animated_sprite_2d.animation != fallback:
			animated_sprite_2d.play(fallback)


# === COMBAT ===
func _attack(num: int) -> void:
	if not enable_combat or is_attacking or is_dodging:
		return
	
	# Check stamina
	if not _consume_stamina(attack_stamina_cost):
		return
	
	is_attacking = true
	_disable_hitbox()
	
	# Only left/right attack animations exist, so map up/down to right/left
	var attack_facing = facing_direction
	if facing_direction == "up" or facing_direction == "down":
		attack_facing = "right"  # Default to right for up/down attacks
	
	var anim_name = "attack_" + str(num) + "_" + attack_facing
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)
	else:
		animated_sprite_2d.play("attack_1_right")
	
	if hitbox:
		match facing_direction:
			"right": hitbox.position = Vector2(hitbox_offset, 0)
			"left": hitbox.position = Vector2(-hitbox_offset, 0)
			"up": hitbox.position = Vector2(0, -hitbox_offset)
			"down": hitbox.position = Vector2(0, hitbox_offset)
	
	await get_tree().create_timer(0.1).timeout
	
	if is_attacking:
		_enable_hitbox()
		await get_tree().create_timer(0.15).timeout
		_disable_hitbox()


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or not enable_combat:
		return
	
	# Cancel dodge on hit (unless invincible during dodge)
	if is_dodging and not dodge_invincibility:
		is_dodging = false
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	if knockback_dir != Vector2.ZERO:
		knockback_velocity = Vector2(knockback_dir.x * 250, -150)
	
	is_attacking = false
	_disable_hitbox()
	
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam.has_method("damage_shake"):
			cam.damage_shake()
			break
	
	_do_invulnerability()
	
	if current_health <= 0:
		player_died.emit()


func instant_kill() -> void:
	if is_invulnerable:
		return
	current_health = 0
	health_changed.emit(current_health, max_health)
	player_died.emit()


func _do_invulnerability() -> void:
	is_invulnerable = true
	for i in range(5):
		animated_sprite_2d.modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		animated_sprite_2d.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	is_invulnerable = false


func _on_animation_finished() -> void:
	if "attack" in animated_sprite_2d.animation:
		is_attacking = false
		_disable_hitbox()
		animated_sprite_2d.play("idle_" + facing_direction)


func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func restore_stamina(amount: float) -> void:
	current_stamina = minf(current_stamina + amount, max_stamina)
	if current_stamina >= max_stamina * 0.3:
		is_stamina_exhausted = false
	stamina_changed.emit(current_stamina, max_stamina)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("Jump") and not is_platformer:
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return 
